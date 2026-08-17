package com.shadowdiary.hsyr

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class BackupFileValidationTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    @Test
    fun acceptsFilesFromEachAllowedCacheDirectory() {
        val cache = temporaryFolder.newFolder("cache")
        val codeCache = temporaryFolder.newFolder("code_cache")
        val regularFile = cache.resolve("backup.zip").apply { writeText("cache") }
        val codeCacheFile = codeCache.resolve("backup.zip").apply { writeText("code cache") }
        val allowedDirectories = listOf(cache, codeCache)

        assertEquals(
            regularFile.canonicalFile,
            validatedFileInDirectories(regularFile.path, allowedDirectories),
        )
        assertEquals(
            codeCacheFile.canonicalFile,
            validatedFileInDirectories(codeCacheFile.path, allowedDirectories),
        )
    }

    @Test
    fun rejectsFilesOutsideAllowedCacheDirectories() {
        val cache = temporaryFolder.newFolder("cache")
        val sibling = temporaryFolder.newFolder("cache-sibling")
        val outsideFile = sibling.resolve("backup.zip").apply { writeText("outside") }

        assertNull(validatedFileInDirectories(outsideFile.path, listOf(cache)))
        assertNull(validatedFileInDirectories(cache.path, listOf(cache)))
    }
}
