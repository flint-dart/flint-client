import 'dart:io';

import 'package:flint_client/flint_client.dart';

Future<void> main() async {
  final client = FlintClient(
    baseUrl: 'https://jsonplaceholder.typicode.com',
    timeout: const Duration(seconds: 15),
    debug: true,
  );

  try {
    // GET
    final getResponse = await client.get<Map<String, dynamic>>('/posts/1');
    print('GET status=${getResponse.statusCode} data=${getResponse.data}');

    // POST
    final postResponse = await client.post<Map<String, dynamic>>(
      '/posts',
      body: {
        'title': 'New Post',
        'body': 'Created with FlintClient',
        'userId': 1,
      },
    );
    print('POST status=${postResponse.statusCode} data=${postResponse.data}');

    // PUT (replace resource)
    final putResponse = await client.put<Map<String, dynamic>>(
      '/posts/1',
      body: {
        'id': 1,
        'title': 'Replaced Title',
        'body': 'Entire object replaced with PUT',
        'userId': 1,
      },
    );
    print('PUT status=${putResponse.statusCode} data=${putResponse.data}');

    // PATCH (partial update)
    final patchResponse = await client.patch<Map<String, dynamic>>(
      '/posts/1',
      body: {'title': 'Patched Title Only'},
    );
    print('PATCH status=${patchResponse.statusCode} data=${patchResponse.data}');

    // DELETE
    final deleteResponse = await client.delete('/posts/1');
    print('DELETE status=${deleteResponse.statusCode}');

    // File download
    final tempDir = Directory.systemTemp;
    final savePath = '${tempDir.path}/flint_example_download.jpg';
    final downloadedFile = await client.downloadFile(
      'https://picsum.photos/400/300',
      savePath: savePath,
      onProgress: (received, total) {
        if (total > 0) {
          final percent = (received / total * 100).toStringAsFixed(0);
          print('Download progress: $percent%');
        }
      },
    );
    print('Downloaded file: ${downloadedFile.path}');

    // File upload (single)
    final uploadResponse = await client.uploadFile<Map<String, dynamic>>(
      'https://httpbin.org/post',
      file: downloadedFile,
      fieldName: 'file',
      body: {'folder': 'examples'},
    );
    print('Upload status=${uploadResponse.statusCode}');
  } finally {
    client.dispose();
  }
}
