# Room (used internally by the workmanager/androidx.work plugin for the
# daily-summary notification) instantiates its generated *_Impl database
# classes via reflection (Class.getDeclaredConstructor()) at runtime. R8's
# default/full mode strips a constructor it can't trace a direct call to,
# which crashes app startup with:
#   NoSuchMethodException: androidx.work.impl.WorkDatabase_Impl.<init> []
# because WorkManager's own androidx.startup initializer runs before
# Flutter loads, with no chance to recover.
-keep class * extends androidx.room.RoomDatabase {
    <init>(...);
}
-keep class **_Impl {
    <init>(...);
}
