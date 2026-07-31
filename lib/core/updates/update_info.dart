class PunhoUpdateInfo {
  const PunhoUpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.mandatory,
    this.releaseNotes,
    this.sha256,
  });

  final String version;
  final int buildNumber;
  final String downloadUrl;
  final bool mandatory;
  final String? releaseNotes;

  /// Impressão digital do APK publicado.
  ///
  /// Sem ela a app **não instala automaticamente** — só oferece o caminho
  /// antigo, pelo browser. O `url_download` vem de uma coluna editável, e uma
  /// app que se instala a si própria tem de confirmar o que está a abrir.
  final String? sha256;

  factory PunhoUpdateInfo.fromJson(Map<String, dynamic> json) =>
      PunhoUpdateInfo(
        version: json['versao_actual'] as String,
        buildNumber: json['build_number'] as int,
        downloadUrl: json['url_download'] as String,
        mandatory: json['obrigatoria'] as bool? ?? false,
        releaseNotes: json['notas_lancamento'] as String?,
        sha256: json['sha256'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'versao_actual': version,
    'build_number': buildNumber,
    'url_download': downloadUrl,
    'obrigatoria': mandatory,
    if (releaseNotes != null) 'notas_lancamento': releaseNotes,
    if (sha256 != null) 'sha256': sha256,
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
    sha256: sha256,
  );
}
