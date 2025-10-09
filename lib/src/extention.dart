import 'dart:io';
import '../flint_client.dart';

extension FlintClientFileSaver on FlintClient {
  /// Saves a [FlintResponse] containing a file or bytes to [path].
  /// Returns the saved [File] or null if the response is not a file.
  Future<File?> saveFile(FlintResponse response, String path) async {
    try {
      final data = response.data;

      if (data is File) {
        // Move or copy existing file to new path
        final file = File(path);
        await data.copy(file.path);
        return file;
      } else if (data is List<int>) {
        // Write bytes to file
        final file = File(path);
        await file.writeAsBytes(data);
        return file;
      } else {
        // Not a file or bytes
        print('FlintClient: Response data is not a file or bytes.');
        return null;
      }
    } catch (e) {
      final err = FlintError('Failed to save file: $e');
      if (onError != null) onError!(err);
      return null;
    }
  }
}
