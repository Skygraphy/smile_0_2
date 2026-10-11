# Release builds shrink the code (R8). WorkManager creates its Room
# database by reflection -- keep the generated classes and their
# constructors, or the app crashes at start (found 2026-10-11).
-keep class * extends androidx.room.RoomDatabase { <init>(...); }
-keep class androidx.work.impl.** { *; }
-keep class androidx.work.** { <init>(...); }
# Our own worker is created by name from WorkManager's database.
-keep class com.smile.smile_app.UploadWorker { <init>(...); }
