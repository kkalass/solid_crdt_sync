// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_notes_app/screens/notes_list_screen.dart';
import 'package:personal_notes_app/services/categories_service.dart';
import 'package:personal_notes_app/services/notes_service.dart';
import 'package:solid_auth/solid_auth.dart';

import 'services/mock_category_repository.dart';
import 'services/mock_note_repository.dart';

void main() {
  testWidgets('Personal Notes App starts up', (WidgetTester tester) async {
    // Create mock repositories and services for testing
    final mockCategoryRepo = MockCategoryRepository();
    final mockNoteRepo = MockNoteRepository();
    final mockNotesService = NotesService(mockNoteRepo);
    final mockCategoriesService = CategoriesService(mockCategoryRepo);

    // Create a mock SolidAuth for testing
    final mockSolidAuth = SolidAuth(
      oidcClientId: 'test-client-id',
      appUrlScheme: 'test-scheme',
      frontendRedirectUrl: Uri.parse('https://test.example.com/redirect'),
    );

    // Build our app with mock services
    await tester.pumpWidget(
      MaterialApp(
        title: 'Personal Notes',
        home: NotesListScreen(
          notesService: mockNotesService,
          categoriesService: mockCategoriesService,
          solidAuth: mockSolidAuth,
        ),
      ),
    );

    // Verify that the app shows the notes list screen
    expect(find.byType(NotesListScreen), findsOneWidget);
  });
}
