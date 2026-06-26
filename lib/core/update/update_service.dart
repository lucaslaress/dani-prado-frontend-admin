import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateInfo {
  final String version;
  final int buildNumber;
  final String downloadUrl;
  final String releaseNotes;

  const UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) => UpdateInfo(
    version: json['version'] as String,
    buildNumber: json['build_number'] as int,
    downloadUrl: json['download_url'] as String,
    releaseNotes: (json['release_notes'] as String?) ?? '',
  );
}

class UpdateService {
  final String versionUrl;

  const UpdateService(this.versionUrl);

  /// Retorna [UpdateInfo] se houver versão mais nova disponível, ou null.
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http
          .get(Uri.parse(versionUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final info = UpdateInfo.fromJson(data);

      final current = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(current.buildNumber) ?? 0;

      return info.buildNumber > currentBuild ? info : null;
    } catch (_) {
      return null;
    }
  }

  /// Baixa o instalador .msix e reporta progresso de 0.0 a 1.0.
  /// Retorna o caminho do arquivo baixado.
  Future<String> downloadInstaller(
    UpdateInfo info,
    void Function(double progress) onProgress,
  ) async {
    final destPath =
        '${Directory.systemTemp.path}\\dani_prado_${info.version}.msix';
    final file = File(destPath);

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(info.downloadUrl));
      final response = await client.send(request);
      final total = response.contentLength ?? 0;
      var received = 0;

      if (response.statusCode != 200) {
        await response.stream.drain();
        throw Exception('Erro ao baixar atualização (HTTP ${response.statusCode})');
      }

      final sink = file.openWrite();
      await for (final chunk in response.stream) {
        received += chunk.length;
        if (total > 0) onProgress(received / total);
        sink.add(chunk);
      }
      await sink.close();
    } finally {
      client.close();
    }

    return destPath;
  }

  /// Abre o instalador MSIX com o App Installer do Windows e encerra o app.
  Future<void> launchInstallerAndExit(String installerPath) async {
    // Escreve um .bat que aguarda o app fechar e abre o MSIX com o App Installer
    final batPath = '${Directory.systemTemp.path}\\dani_prado_update.bat';
    final bat = File(batPath);
    await bat.writeAsString(
      '@echo off\r\n'
      'ping -n 4 127.0.0.1 > nul\r\n'
      'start "" "$installerPath"\r\n',
    );

    await Process.start(
      'cmd.exe',
      ['/c', batPath],
      mode: ProcessStartMode.detached,
    );

    await Future.delayed(const Duration(milliseconds: 300));
    exit(0);
  }
}
