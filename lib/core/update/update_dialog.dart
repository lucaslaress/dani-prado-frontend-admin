import 'package:flutter/material.dart';

import 'update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  final UpdateService service;

  const UpdateDialog({super.key, required this.info, required this.service});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  _Phase _phase = _Phase.idle;
  double _progress = 0;
  String? _error;

  Future<void> _startUpdate() async {
    setState(() {
      _phase = _Phase.downloading;
      _error = null;
      _progress = 0;
    });

    try {
      final path = await widget.service.downloadInstaller(
        widget.info,
        (p) => setState(() => _progress = p),
      );
      setState(() => _phase = _Phase.installing);
      await widget.service.launchInstallerAndExit(path);
    } catch (_) {
      if (mounted) {
        setState(() {
          _phase = _Phase.idle;
          _error = 'Erro no download. Verifique a conexão e tente novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase == _Phase.idle,
      child: AlertDialog(
        title: const Text('Atualização disponível'),
        content: _buildContent(),
        actions: _phase == _Phase.idle ? _buildActions() : null,
      ),
    );
  }

  Widget _buildContent() {
    return SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nova versão: ${widget.info.version}'),
          if (widget.info.releaseNotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.info.releaseNotes,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
          ],
          if (_phase == _Phase.downloading) ...[
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
            ),
            const SizedBox(height: 6),
            Text(
              _progress > 0
                  ? 'Baixando... ${(_progress * 100).toInt()}%'
                  : 'Iniciando download...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_phase == _Phase.installing) ...[
            const SizedBox(height: 20),
            const LinearProgressIndicator(),
            const SizedBox(height: 6),
            const Text('Instalando... O app será reaberto automaticamente.'),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildActions() => [
    TextButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('Depois'),
    ),
    ElevatedButton(
      onPressed: _startUpdate,
      child: const Text('Atualizar agora'),
    ),
  ];
}

enum _Phase { idle, downloading, installing }
