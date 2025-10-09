/// File operations example for Flint HTTP Client
///
/// This example demonstrates file upload and download capabilities
/// including progress tracking and file management.
library;

import 'dart:io';

import 'package:flint_client/flint_client.dart';

void main() async {
  final client = FlintClient(
    baseUrl: 'https://httpbin.org', // Testing service that echoes back
    debug: true,
  );

  try {
    // File download with progress tracking
    print('=== File Download ===');
    final tempDir = Directory.systemTemp;
    final savePath = 'downloaded/downloaded_image.jpg';

    await client.downloadFile(
      'https://picsum.photos/400/300', // Random image
      savePath: savePath,
      onProgress: (received, total) {
        if (total > 0) {
          final percentage = (received / total * 100).round();
          print('Download progress: $percentage% ($received/$total bytes)');
        }
      },
      onError: (error) {
        print('Download failed: ${error.message}');
      },
    );

    final downloadedFile = File(savePath);
    if (await downloadedFile.exists()) {
      final length = await downloadedFile.length();
      print('✅ File downloaded successfully: $savePath ($length bytes)');
    }

    // File upload with multipart form data
    print('\n=== File Upload ===');

    // Create a test file to upload
    final testFile = File('${tempDir.path}/test_upload.txt');
    await testFile.writeAsString('Hello from Flint HTTP Client!');

    final uploadResponse = await client.post<Map<String, dynamic>>(
      '/post',
      files: {
        'file': testFile,
        'avatar': downloadedFile, // Upload the file we just downloaded
      },
      body: {'name': 'Test User', 'description': 'File upload test'},
      onSendProgress: (sent, total) {
        if (total > 0) {
          final percentage = (sent / total * 100).round();
          print('Upload progress: $percentage% ($sent/$total bytes)');
        }
      },
      parser: (json) => json as Map<String, dynamic>,
    );

    if (uploadResponse.isSuccess) {
      print('✅ File upload successful');
      final responseData = uploadResponse.data!;
      print('Response: ${responseData['headers']}');
      print('Form data: ${responseData['form']}');
    }

    // Multiple file uploads
    print('\n=== Multiple File Upload ===');

    // Create multiple test files
    final file1 = File('${tempDir.path}/file1.txt');
    final file2 = File('${tempDir.path}/file2.txt');
    await file1.writeAsString('This is file 1 content');
    await file2.writeAsString('This is file 2 content');

    final multiUploadResponse = await client.post<Map<String, dynamic>>(
      '/post',
      files: {'documents': file1, 'attachments': file2},
      body: {'title': 'Multiple files', 'category': 'test'},
      onSendProgress: (sent, total) {
        final percentage = (sent / total * 100).round();
        print('Multi-file upload: $percentage%');
      },
    );

    if (multiUploadResponse.isSuccess) {
      print('✅ Multiple files uploaded successfully');
    }

    // Clean up temporary files
    print('\n=== Cleanup ===');
    await Future.wait([
      if (await downloadedFile.exists()) downloadedFile.delete(),
      if (await testFile.exists()) testFile.delete(),
      if (await file1.exists()) file1.delete(),
      if (await file2.exists()) file2.delete(),
    ]);
    print('Temporary files cleaned up');
  } catch (e) {
    print('Error during file operations: $e');
  } finally {
    client.dispose();
  }
}
