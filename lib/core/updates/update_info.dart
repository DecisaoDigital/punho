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
}
