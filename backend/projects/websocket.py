import asyncio
import json
import re
from collections import defaultdict
from urllib.parse import parse_qs

from asgiref.sync import sync_to_async
from rest_framework.authtoken.models import Token

from .models import ChatRoom, Message
from .serializers import MessageSerializer


CHAT_ROOM_PATH = re.compile(r"^/ws/chat-rooms/(?P<room_id>\d+)/?$")
room_connections = defaultdict(set)


async def chat_websocket_app(scope, receive, send):
    match = CHAT_ROOM_PATH.match(scope.get("path", ""))
    if not match:
        await send({"type": "websocket.close", "code": 4404})
        return

    room_id = int(match.group("room_id"))
    token_key = _token_from_scope(scope)
    user = await _get_user_from_token(token_key)

    if user is None:
        await send({"type": "websocket.close", "code": 4401})
        return

    is_member = await _is_room_member(room_id, user.id)
    if not is_member:
        await send({"type": "websocket.close", "code": 4403})
        return

    await send({"type": "websocket.accept"})

    queue = asyncio.Queue()
    room_connections[room_id].add(queue)

    sender_task = asyncio.create_task(_send_from_queue(queue, send))
    try:
        while True:
            event = await receive()

            if event["type"] == "websocket.disconnect":
                break

            if event["type"] != "websocket.receive":
                continue

            content = _content_from_event(event)
            if not content:
                await _send_error(send, "메시지 내용은 필수입니다.")
                continue

            message_data = await _create_message(room_id, user.id, content)
            await _broadcast(room_id, message_data)
    finally:
        room_connections[room_id].discard(queue)
        if not room_connections[room_id]:
            room_connections.pop(room_id, None)
        sender_task.cancel()


def _token_from_scope(scope):
    query_string = scope.get("query_string", b"").decode()
    query = parse_qs(query_string)
    values = query.get("token", [])
    return values[0] if values else None


@sync_to_async
def _get_user_from_token(token_key):
    if not token_key:
        return None

    try:
        return Token.objects.select_related("user").get(key=token_key).user
    except Token.DoesNotExist:
        return None


@sync_to_async
def _is_room_member(room_id, user_id):
    return ChatRoom.objects.filter(id=room_id, members__id=user_id).exists()


@sync_to_async
def _create_message(room_id, user_id, content):
    message = Message.objects.create(
        chat_room_id=room_id,
        sender_id=user_id,
        content=content,
    )
    return MessageSerializer(message).data


def _content_from_event(event):
    raw = event.get("text")
    if raw is None and event.get("bytes") is not None:
        raw = event["bytes"].decode()

    if not raw:
        return ""

    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return raw.strip()

    if isinstance(payload, dict):
        return str(payload.get("content", "")).strip()

    return str(payload).strip()


async def _broadcast(room_id, payload):
    dead_queues = []
    for queue in tuple(room_connections.get(room_id, ())):
        try:
            queue.put_nowait(payload)
        except RuntimeError:
            dead_queues.append(queue)

    for queue in dead_queues:
        room_connections[room_id].discard(queue)


async def _send_from_queue(queue, send):
    while True:
        payload = await queue.get()
        await send(
            {
                "type": "websocket.send",
                "text": json.dumps(payload, ensure_ascii=False),
            }
        )


async def _send_error(send, message):
    await send(
        {
            "type": "websocket.send",
            "text": json.dumps(
                {"type": "error", "message": message},
                ensure_ascii=False,
            ),
        }
    )
