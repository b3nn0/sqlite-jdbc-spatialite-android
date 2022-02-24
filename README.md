# sqlite-jdbc-spatialite-android
Script to compile sqlite-jdbc with Spatialite for Android

Hopefully, just define $NDKROOT, then run
```
./download.sh
./build.sh
```

might have to get creative at some point...

Right now, only GEOS, RTTOPO and PROJ modules are built in. More could probably be added relatively simple, but I don't need them.

The resulting jar will be placed in the target/ directory.
The native library is packed right into the jar, so you only need to add the jar to your build.gradle.

Note: For proper libproj support, your code will have to extract the resource `proj.db` to some directory and call `PROJ_SetDatabasePath(...)` at some point.
i.e. soemthing like this (you have to replace the SQL calls with however you do them of course)
```
    private void initProjForSpatialite() throws SQLException, IOException {
        String projVersion = DbUtil.queryForString(this.db, "SELECT proj_version()");
        String[] parts = projVersion.split(" ");
        if (parts.length >= 2) {
            projVersion = parts[1];
            projVersion = projVersion.replace(",", "");
        }
        File projDb = new File(context.getExternalCacheDir(), "proj.db-" + projVersion);
        if (!projDb.exists()) {
            // Extract from resources
            InputStream dbStream = Context.class.getClassLoader().getResourceAsStream("proj.db");
            FileOutputStream fos = new FileOutputStream(projDb);
            byte[] buf = new byte[4096];
            int length;
            while ((length = dbStream.read(buf)) > 0) {
                fos.write(buf, 0, length);
            }
            dbStream.close();
            fos.close();
        }
        DbUtil.queryForString(this.db, "SELECT PROJ_SetDatabasePath(?)", projDb.getAbsolutePath());
    }
```