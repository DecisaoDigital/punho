package pt.decisaodigital.punho

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity é exigido pelo local_auth para mostrar o prompt
// de biometria (BiometricPrompt vive num Fragment).
class MainActivity : FlutterFragmentActivity() {

    private val canalInstalador = "punho/instalador"

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, canalInstalador)
            .setMethodCallHandler { chamada, resultado ->
                when (chamada.method) {
                    // O Android exige que o utilizador autorize esta app a
                    // instalar pacotes. Só se pergunta quando faz falta — pedir
                    // isto no arranque assustava sem motivo nenhum.
                    "podeInstalar" -> resultado.success(podeInstalar())
                    "pedirPermissao" -> {
                        abrirDefinicoesDeInstalacao()
                        resultado.success(null)
                    }
                    "instalar" -> {
                        val caminho = chamada.argument<String>("caminho")
                        if (caminho == null) {
                            resultado.error("sem_caminho", "falta o caminho do APK", null)
                        } else {
                            InstaladorDeApk.instalar(applicationContext, caminho, resultado)
                        }
                    }
                    else -> resultado.notImplemented()
                }
            }
    }

    private fun podeInstalar(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }

    private fun abrirDefinicoesDeInstalacao() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        startActivity(
            Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }
}
