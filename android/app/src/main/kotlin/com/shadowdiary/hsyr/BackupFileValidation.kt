package com.shadowdiary.hsyr

import java.io.File
import java.io.IOException

internal fun validatedFileInDirectories(path: String, directories: List<File>): File? {
    return try {
        val file = File(path).canonicalFile
        val isInAllowedDirectory = directories.any { directory ->
            val prefix = directory.canonicalFile.path + File.separator
            file.path.startsWith(prefix)
        }
        if (!isInAllowedDirectory || !file.isFile || !file.canRead()) null else file
    } catch (_: IOException) {
        null
    }
}
