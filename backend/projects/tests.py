from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import User
from .models import Application, ChatRoom, Project


class ApplicantApprovalChatRoomTests(APITestCase):
    def setUp(self):
        self.owner = User.objects.create_user(
            username='owner',
            email='owner@example.com',
            password='password123',
        )
        self.applicant = User.objects.create_user(
            username='applicant',
            email='applicant@example.com',
            password='password123',
        )
        self.project = Project.objects.create(
            title='Test Project',
            owner=self.owner,
            recruit_count=3,
        )
        self.chat_room = ChatRoom.objects.create(
            project=self.project,
            name='Test Project 채팅방',
        )
        self.chat_room.members.add(self.owner)
        self.application = Application.objects.create(
            user=self.applicant,
            project=self.project,
        )

    def test_approving_applicant_adds_them_to_project_chat_room(self):
        self.assertFalse(self.chat_room.members.filter(id=self.applicant.id).exists())

        self.client.force_authenticate(user=self.owner)
        url = reverse(
            'project-approve-applicant',
            kwargs={'pk': self.project.id, 'user_id': self.applicant.id},
        )
        response = self.client.post(url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['added_chat_rooms'], 1)

        self.application.refresh_from_db()
        self.chat_room.refresh_from_db()
        self.assertEqual(self.application.status, 'accepted')
        self.assertTrue(self.chat_room.members.filter(id=self.applicant.id).exists())

        self.client.force_authenticate(user=self.applicant)
        response = self.client.get(reverse('chat-room-list'))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['id'], self.chat_room.id)
