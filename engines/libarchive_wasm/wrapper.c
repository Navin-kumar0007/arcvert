// The little the browser's archive worker needs from libarchive. Reads return real byte counts, so a
// damaged file can't pass for a whole one, and the worker counts what really comes out.

#include <archive.h>
#include <archive_entry.h>
#include <emscripten.h>
#include <locale.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>

// Only the formats wanted, so nothing else in the library ever sees a stranger's file.
EMSCRIPTEN_KEEPALIVE
struct archive *radial_open(const void *bytes, size_t size) {
  // Without this any name that isn't plain English comes back empty.
  setlocale(LC_ALL, "C.UTF-8");
  struct archive *archive = archive_read_new();
  if (archive == NULL) return NULL;
  archive_read_support_format_7zip(archive);
  archive_read_support_format_rar(archive);
  archive_read_support_format_rar5(archive);
  // If this fails, reading the first entry says why.
  archive_read_open_memory(archive, bytes, size);
  return archive;
}

// One part of a RAR in several, held in memory.
struct radial_part {
  const unsigned char *bytes;
  size_t size;
  size_t at;
};

// The parts of the archive open now. A worker opens one archive at a time.
static struct radial_part *open_parts = NULL;

static la_ssize_t part_read(struct archive *archive, void *data, const void **buffer) {
  struct radial_part *part = data;
  *buffer = part->bytes + part->at;
  size_t left = part->size - part->at;
  part->at = part->size;
  return (la_ssize_t)left;
}

static la_int64_t part_skip(struct archive *archive, void *data, la_int64_t request) {
  struct radial_part *part = data;
  la_int64_t left = (la_int64_t)(part->size - part->at);
  if (request > left) request = left;
  if (request < 0) request = 0;
  part->at += (size_t)request;
  return request;
}

static la_int64_t part_seek(struct archive *archive, void *data, la_int64_t offset, int whence) {
  struct radial_part *part = data;
  la_int64_t to;
  switch (whence) {
    case SEEK_SET: to = offset; break;
    case SEEK_CUR: to = (la_int64_t)part->at + offset; break;
    case SEEK_END: to = (la_int64_t)part->size + offset; break;
    default: return ARCHIVE_FATAL;
  }
  if (to < 0) return ARCHIVE_FATAL;
  if (to > (la_int64_t)part->size) to = (la_int64_t)part->size;
  part->at = (size_t)to;
  return to;
}

// Moving on to the next part starts at its beginning.
static int part_switch(struct archive *archive, void *done, void *next) {
  if (next != NULL) ((struct radial_part *)next)->at = 0;
  return ARCHIVE_OK;
}

// A RAR in several parts, read one after another as one archive, as archive_read_open_filenames
// does with files. [bytes] and [sizes] hold each part's place and size, first part first.
EMSCRIPTEN_KEEPALIVE
struct archive *radial_open_parts(const void *const *bytes, const size_t *sizes, int count) {
  setlocale(LC_ALL, "C.UTF-8");
  struct archive *archive = archive_read_new();
  if (archive == NULL || count < 1) return NULL;
  archive_read_support_format_rar(archive);
  archive_read_support_format_rar5(archive);
  free(open_parts);
  open_parts = calloc((size_t)count, sizeof *open_parts);
  if (open_parts == NULL) {
    archive_read_free(archive);
    return NULL;
  }
  archive_read_set_read_callback(archive, part_read);
  archive_read_set_skip_callback(archive, part_skip);
  archive_read_set_seek_callback(archive, part_seek);
  archive_read_set_switch_callback(archive, part_switch);
  for (int i = 0; i < count; i++) {
    open_parts[i].bytes = bytes[i];
    open_parts[i].size = sizes[i];
    archive_read_append_callback_data(archive, &open_parts[i]);
  }
  // If this fails, reading the first entry says why.
  archive_read_open1(archive);
  return archive;
}

// The next entry, 0 at the end, or -1 if the archive can't be read further.
EMSCRIPTEN_KEEPALIVE
long radial_next(struct archive *archive) {
  struct archive_entry *entry = NULL;
  int result;
  do {
    result = archive_read_next_header(archive, &entry);
  } while (result == ARCHIVE_RETRY);
  if (result == ARCHIVE_EOF) return 0;
  if (result != ARCHIVE_OK && result != ARCHIVE_WARN) return -1;
  return (long)entry;
}

// Links stay out, so they can't point anywhere.
EMSCRIPTEN_KEEPALIVE
int radial_is_regular_file(struct archive_entry *entry) {
  return archive_entry_filetype(entry) == AE_IFREG && archive_entry_hardlink(entry) == NULL;
}

EMSCRIPTEN_KEEPALIVE
int radial_is_encrypted(struct archive_entry *entry) {
  return archive_entry_is_encrypted(entry) > 0;
}

EMSCRIPTEN_KEEPALIVE
const char *radial_name(struct archive_entry *entry) {
  return archive_entry_pathname_utf8(entry);
}

// How many bytes were read, 0 at the end of the file, or below 0 if it failed.
EMSCRIPTEN_KEEPALIVE
long radial_read(struct archive *archive, void *buffer, size_t size) {
  la_ssize_t count;
  do {
    count = archive_read_data(archive, buffer, size);
  } while (count == ARCHIVE_RETRY);
  return (long)count;
}

EMSCRIPTEN_KEEPALIVE
const char *radial_error(struct archive *archive) {
  const char *message = archive_error_string(archive);
  return message == NULL ? "" : message;
}

EMSCRIPTEN_KEEPALIVE
void radial_close(struct archive *archive) {
  archive_read_free(archive);
  free(open_parts);
  open_parts = NULL;
}
