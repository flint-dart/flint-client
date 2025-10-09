import 'package:flint_client/flint_client.dart';

/// Basic usage example for Flint HTTP Client
///
/// This example demonstrates the fundamental usage of FlintClient
/// for common HTTP operations like GET, POST, PUT, and DELETE.

// Example data model
class User {
  final int id;
  final String name;
  final String email;

  User({required this.id, required this.name, required this.email});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(id: json['id'], name: json['name'], email: json['email']);
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};

  @override
  String toString() => 'User(id: $id, name: $name, email: $email)';
}

void main() async {
  // Create a FlintClient instance with base URL
  final client = FlintClient(
    baseUrl: 'https://jsonplaceholder.typicode.com',
    debug: true, // Enable debug logging
  );

  try {
    // GET request - Fetch a user
    print('=== GET Request ===');
    final userResponse = await client.get<User>(
      '/users/1',
      parser: (json) => User.fromJson(json),
    );

    if (userResponse.isSuccess) {
      print('User fetched: ${userResponse.data}');
    }

    // POST request - Create a new user
    print('\n=== POST Request ===');
    final newUser = User(id: 101, name: 'John Doe', email: 'john@example.com');
    final createResponse = await client.post<User>(
      '/users',
      body: newUser.toJson(),
      parser: (json) => User.fromJson(json),
    );

    if (createResponse.isSuccess) {
      print('User created: ${createResponse.data}');
    }

    // PUT request - Update a user
    print('\n=== PUT Request ===');
    final updatedUser = User(
      id: 1,
      name: 'Jane Smith',
      email: 'jane@example.com',
    );
    final updateResponse = await client.put<User>(
      '/users/1',
      body: updatedUser.toJson(),
      parser: (json) => User.fromJson(json),
    );

    if (updateResponse.isSuccess) {
      print('User updated: ${updateResponse.data}');
    }

    // DELETE request - Remove a user
    print('\n=== DELETE Request ===');
    final deleteResponse = await client.delete<void>('/users/1');

    if (deleteResponse.isSuccess) {
      print('User deleted successfully');
    }

    // PATCH request - Partial update
    print('\n=== PATCH Request ===');
    final patchResponse = await client.patch<User>(
      '/users/1',
      body: {'name': 'Updated Name'},
      parser: (json) => User.fromJson(json),
    );

    if (patchResponse.isSuccess) {
      print('User patched: ${patchResponse.data}');
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    // Always dispose the client when done
    client.dispose();
  }
}
