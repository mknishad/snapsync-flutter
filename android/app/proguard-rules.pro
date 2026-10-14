# R8 rules for the release build, added on top of the Android defaults and the
# rules the Flutter Gradle plugin applies for the Flutter embedding.
#
# Each plugin used by SnapSync (workmanager, sqflite, camera, permission_handler,
# connectivity_plus, path_provider) registers through the Flutter plugin
# registrant and ships its own consumer rules. Add a rule below only when R8
# reports a missing class or a release-only crash proves one is needed, and say
# why next to it. No blanket keep or dontwarn rules.
