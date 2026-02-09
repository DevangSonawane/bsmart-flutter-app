import 'api_client.dart';

/// REST API wrapper for `/upload` endpoint.
///
/// Endpoint:
///   POST /upload – Upload a single file (protected, multipart/form-data)
class UploadApi {
  static final UploadApi _instance = UploadApi._internal();
  factory UploadApi() => _instance;
  UploadApi._internal();

  final ApiClient _client = ApiClient();

  /// Upload a file from a local path.
  ///
  /// Returns `{ fileName: String, fileUrl: String }`.
  Future<Map<String, dynamic>> uploadFile(String filePath) async {
    final res = await _client.multipartPost(
      '/upload',
      filePath: filePath,
      fileField: 'file',
    );
    return res as Map<String, dynamic>;
  }

  /// Upload a file from raw bytes (e.g. from image picker).
  ///
  /// Returns `{ fileName: String, fileUrl: String }`.
  Future<Map<String, dynamic>> uploadFileBytes({
    required List<int> bytes,
    required String filename,
  }) async {
    final res = await _client.multipartPostBytes(
      '/upload',
      bytes: bytes,
      filename: filename,
      fileField: 'file',
    );
    return res as Map<String, dynamic>;
  }
}
