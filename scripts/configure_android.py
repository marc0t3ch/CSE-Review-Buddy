from pathlib import Path
p=Path('android/app/src/main/AndroidManifest.xml')
s=p.read_text()
if 'POST_NOTIFICATIONS' not in s:
    s=s.replace('<application', '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>\n    <application',1)
if 'ScheduledNotificationReceiver' not in s:
    s=s.replace('</application>', """<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
          <intent-filter>
            <action android:name="android.intent.action.BOOT_COMPLETED" />
            <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
          </intent-filter>
        </receiver>
    </application>""",1)
p.write_text(s)
# Plugin 17 requires Java 8+ core library desugaring
for path in [Path('android/app/build.gradle'),Path('android/app/build.gradle.kts')]:
    if not path.exists():continue
    b=path.read_text()
    if path.suffix=='.kts':
        b=b.replace('compileOptions {','compileOptions {\n        isCoreLibraryDesugaringEnabled = true',1)
        b += '\ndependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4") }\n'
    else:
        b=b.replace('compileOptions {','compileOptions {\n        coreLibraryDesugaringEnabled true',1)
        b += "\ndependencies { coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4' }\n"
    path.write_text(b)

# Set each Kotlin task's JVM target to match its corresponding Java task.
# Android plugins use different targets (e.g. Java 11 and Java 17).
root = Path('android/build.gradle.kts')
if root.exists():
    b = root.read_text()
    b += '''

subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        val javaTaskName = name.replace("Kotlin", "JavaWithJavac")
        val javaTask = tasks.findByName(javaTaskName) as? org.gradle.api.tasks.compile.JavaCompile
        if (javaTask != null) {
            compilerOptions.jvmTarget.set(
                org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget(javaTask.targetCompatibility)
            )
        }
    }
}
'''
    root.write_text(b)
