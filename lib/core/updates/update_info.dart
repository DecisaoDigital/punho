class PunhoUpdateInfo {
  const PunhoUpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.mandatory,
    this.releaseNotes,
  });

  final String version;
  final int buildNumber;
  final String downloadUrl;
  final bool mandatory;
  final String? releaseNotes;

  factory PunhoUpdateInfo.fromJson(Map<String, dynamic> json) =>
      PunhoUpdateInfo(
        version: json['versao_actual'] as String,
        buildNumber: json['build_number'] as int,
        downloadUrl: json['url_download'] as String,
        mandatory: json['obrigatoria'] as bool? ?? false,
        releaseNotes: json['notas_lancamento'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'versao_actual': version,
    'build_number': buildNumber,
    'url_download': downloadUrl,
    'obrigatoria': mandatory,
    if (releaseNotes != null) 'notas_lancamento': releaseNotes,
  };

  /// A mesma versão, mas sem poder bloquear a app.
  ///
  /// Só uma resposta viva do servidor tem autoridade para prender o utilizador
  /// fora da app. Um `obrigatoria: true` vindo do cache local significaria que
  /// retirar a linha de `versoes_apps` deixava o telemóvel bloqueado para
  /// sempre, sem forma de recuperar sem limpar os dados da app.
  PunhoUpdateInfo semBloqueio() => PunhoUpdateInfo(
    version: version,
    buildNumber: buildNumber,
    downloadUrl: downloadUrl,
    mandatory: false,
    releaseNotes: releaseNotes,
  );
}
