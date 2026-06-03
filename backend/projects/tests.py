from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from accounts.models import User
from .models import Application, ChatRoom, Project, ProjectEvaluation


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


class ProjectCompleteAndEvaluateTests(APITestCase):
    def setUp(self):
        self.owner = User.objects.create_user(
            username='owner2',
            email='owner2@example.com',
            password='password123',
        )
        self.applicant = User.objects.create_user(
            username='applicant2',
            email='applicant2@example.com',
            password='password123',
        )
        self.project = Project.objects.create(
            title='Evaluation Project',
            owner=self.owner,
            recruit_count=2,
        )
        self.application = Application.objects.create(
            user=self.applicant,
            project=self.project,
            status='accepted',
        )

    def test_complete_endpoint_sets_project_status(self):
        self.client.force_authenticate(user=self.owner)
        response = self.client.post(reverse('project-complete', kwargs={'pk': self.project.id}))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['project_status'], '완료')
        self.assertFalse(response.data['all_members_submitted'])
        self.assertEqual(response.data['required_members_count'], 2)
        self.assertEqual(response.data['submitted_members_count'], 0)

        self.project.refresh_from_db()
        self.assertEqual(self.project.status, '완료')

    def test_evaluate_endpoint_reports_submission_progress(self):
        self.client.force_authenticate(user=self.owner)
        complete_response = self.client.post(reverse('project-complete', kwargs={'pk': self.project.id}))
        self.assertEqual(complete_response.status_code, status.HTTP_200_OK)

        response = self.client.post(
            reverse('project-evaluate', kwargs={'pk': self.project.id}),
            {'score': 5, 'feedback': '좋은 프로젝트였습니다.'},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertFalse(response.data['all_members_submitted'])
        self.assertEqual(response.data['submitted_members_count'], 1)

        self.client.force_authenticate(user=self.applicant)
        response = self.client.post(
            reverse('project-evaluate', kwargs={'pk': self.project.id}),
            {'score': 4, 'feedback': '참여 경험이 좋았습니다.'},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(response.data['all_members_submitted'])
        self.assertEqual(response.data['submitted_members_count'], 2)

        evaluations = ProjectEvaluation.objects.filter(project=self.project)
        self.assertEqual(evaluations.count(), 2)
