allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory
    .dir("../../build")
    .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")

    // 🔥 DÜZELTME BURADA: Senin yazdığın mantığı bir değişkene atadık
    // Böylece hem "hemen şimdi" hem de "sonra" çalıştırabilir hale geldik.
    val configureNamespaceAction = {
        if (extensions.findByName("android") != null) {
            val androidExtension = extensions.getByName("android") as com.android.build.gradle.BaseExtension
            if (androidExtension.namespace == null) {
                androidExtension.namespace = group.toString()
            }
        }
    }

    // Hata veren kısmı bu kontrol ile değiştirdik:
    if (project.state.executed) {
        configureNamespaceAction() // Zaten hazırsan hemen çalıştır
    } else {
        afterEvaluate {
            configureNamespaceAction() // Değilsen hazır olunca çalıştır
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}