import 'dart:io';
import 'package:flint_client/flint_client.dart';
import 'package:flint_client/src/flint_response.dart';

void main() async {
  // Create a FlintClient instance
  final client = FlintClient(
    baseUrl: 'https://fakestoreapi.com',
    headers: {'Accept': 'application/json'},
    onError: (error) => print('Error occurred: ${error.message}'),
  );

  // 1️⃣ GET all products
  final FlintResponse productsResponse = await client.get('/products');

  if (!productsResponse.isError && productsResponse.data != null) {
    print('Products fetched:');
    for (var product in productsResponse.data!) {
      print(' - ${product['title']} (\$${product['price']})');
    }
  }

  // 2️⃣ GET single product
  final FlintResponse singleProductResponse = await client.get('/products/1');

  if (!singleProductResponse.isError && singleProductResponse.data != null) {
    print('\nSingle product fetched:');
    print(singleProductResponse.data);
  }

  // 3️⃣ PATCH request to update product
  final updateBody = {'title': 'Updated Product Title'};
  final FlintResponse patchResponse = await client.patch(
    '/products/1',
    body: updateBody,
  );

  if (!patchResponse.isError && patchResponse.data != null) {
    print('\nProduct updated:');
    print(patchResponse.data);
  }

  // 4️⃣ GET a file (example)
  final fileResponse = await client.get(
    '/products/download',
    saveFilePath: 'product_image.png',
  );
  if (!fileResponse.isError && fileResponse.data is File) {
    final file = fileResponse.data as File;
    print('\nFile saved at: ${file.path}');
  }

  print('\nAll requests completed!');
}
