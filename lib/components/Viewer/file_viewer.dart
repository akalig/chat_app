import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class FileViewer {

  // Method for Conditional File Viewing
  static Future<void> viewFile({
    required BuildContext context,
    required String fileName,
    required String fileExtension,
    required Uint8List fileData,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(fileData);

      switch (fileExtension.toLowerCase()) {
        case '.png':
        case '.jpg':
        case '.jpeg':
        case '.gif':
          await _viewImage(context, file);
          break;
        case '.pdf':
          await _viewPdf(context, file);
          break;
        case '.doc':
        case '.docx':
        case '.xls':
        case '.xlsx':
        case '.ppt':
        case '.pptx':
          await _viewOfficeFile(context, file);
          break;
        case '.txt':
        case '.csv':
        case '.html':
        case '.xml':
          await _viewTextFile(context, file);
          break;
        default:
          _showUnsupportedDialog(context);
      }
    } catch (e) {
      _showErrorDialog(context, 'Failed to open file: ${e.toString()}');
    }
  }

  // Method for Image Viewing
  static Future<void> _viewImage(BuildContext context, File file) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => Scaffold(
              appBar: AppBar(title: Text('Image Viewer')),
              body: PhotoView(imageProvider: FileImage(file)),
            ),
      ),
    );
  }

  // Method for PDF Viewing
  static Future<void> _viewPdf(BuildContext context, File file) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => Scaffold(
              appBar: AppBar(title: Text('PDF Viewer')),
              body: SfPdfViewer.file(file),
            ),
      ),
    );
  }

  // Method for MS/Office Files Viewing
  static Future<void> _viewOfficeFile(BuildContext context, File file) async {
    final result = await OpenFilex.open(file.path);

    if (result.type != ResultType.done) {
      _showErrorDialog(
          context,
          "No viewer app found. Try installing a free office suite like WPS Office."
      );
    }
  }

  // Method for Raw Text Viewing
  static Future<void> _viewTextFile(BuildContext context, File file) async {
    final content = await file.readAsString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => Scaffold(
              appBar: AppBar(title: Text('Text Viewer')),
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: SelectableText(content),
                ),
              ),
            ),
      ),
    );
  }

  // Method for Unsupported Files
  static void _showUnsupportedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Unsupported Format'),
            content: Text('This file type cannot be previewed.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
    );
  }

  // Method for Errors
  static void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
    );
  }
}
