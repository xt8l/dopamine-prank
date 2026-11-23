#import "DOZipHelper.h"
#import <zlib.h>

#pragma pack(push, 1)
typedef struct {
    uint32_t signature;
    uint16_t versionNeeded;
    uint16_t flags;
    uint16_t compression;
    uint16_t modTime;
    uint16_t modDate;
    uint32_t crc32;
    uint32_t compressedSize;
    uint32_t uncompressedSize;
    uint16_t filenameLen;
    uint16_t extraLen;
} ZipLocalFileHeader;

typedef struct {
    uint32_t signature;
    uint16_t versionMadeBy;
    uint16_t versionNeeded;
    uint16_t flags;
    uint16_t compression;
    uint16_t modTime;
    uint16_t modDate;
    uint32_t crc32;
    uint32_t compressedSize;
    uint32_t uncompressedSize;
    uint16_t filenameLen;
    uint16_t extraLen;
    uint16_t commentLen;
    uint16_t diskStart;
    uint16_t internalAttr;
    uint32_t externalAttr;
    uint32_t localHeaderOffset;
} ZipCentralDirEntry;

typedef struct {
    uint32_t signature;
    uint16_t diskNumber;
    uint16_t centralDirDisk;
    uint16_t centralDirRecordsOnDisk;
    uint16_t centralDirRecordsTotal;
    uint32_t centralDirSize;
    uint32_t centralDirOffset;
    uint16_t commentLen;
} ZipEndOfCentralDir;
#pragma pack(pop)

#define ZIP_LOCAL_SIG  0x04034b50
#define ZIP_CENTRAL_SIG 0x02014b50
#define ZIP_EOCD_SIG   0x06054b50

@implementation DOZipHelper

+ (BOOL)unzipFileAtPath:(NSString *)zipPath toDirectory:(NSString *)destDir error:(NSError **)error {
    NSData *zipData = [NSData dataWithContentsOfFile:zipPath options:NSDataReadingMappedIfSafe error:error];
    if (!zipData) return NO;

    const uint8_t *bytes = zipData.bytes;
    NSUInteger len = zipData.length;

    // Find End of Central Directory
    NSInteger eocdPos = -1;
    for (NSInteger i = len - sizeof(ZipEndOfCentralDir); i >= 0 && i >= (NSInteger)(len - 65557); i--) {
        uint32_t sig;
        memcpy(&sig, bytes + i, 4);
        if (sig == ZIP_EOCD_SIG) { eocdPos = i; break; }
    }
    if (eocdPos < 0) {
        if (error) *error = [NSError errorWithDomain:@"DOZip" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Not a valid ZIP file"}];
        return NO;
    }

    ZipEndOfCentralDir eocd;
    memcpy(&eocd, bytes + eocdPos, sizeof(eocd));

    uint32_t cdOffset = eocd.centralDirOffset;
    uint16_t numEntries = eocd.centralDirRecordsTotal;
    NSFileManager *fm = [NSFileManager defaultManager];

    uint32_t pos = cdOffset;
    for (uint16_t i = 0; i < numEntries; i++) {
        if (pos + sizeof(ZipCentralDirEntry) > len) break;
        ZipCentralDirEntry cd;
        memcpy(&cd, bytes + pos, sizeof(cd));
        if (cd.signature != ZIP_CENTRAL_SIG) break;

        NSString *filename = [[NSString alloc] initWithBytes:bytes + pos + sizeof(cd) length:cd.filenameLen encoding:NSUTF8StringEncoding];
        if (!filename) filename = [[NSString alloc] initWithBytes:bytes + pos + sizeof(cd) length:cd.filenameLen encoding:NSASCIIStringEncoding];

        pos += sizeof(cd) + cd.filenameLen + cd.extraLen + cd.commentLen;

        if (!filename || [filename hasPrefix:@"__MACOSX"]) continue;

        NSString *outPath = [destDir stringByAppendingPathComponent:filename];

        if ([filename hasSuffix:@"/"]) {
            [fm createDirectoryAtPath:outPath withIntermediateDirectories:YES attributes:nil error:nil];
            continue;
        }

        [fm createDirectoryAtPath:[outPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];

        // Read from local file header
        uint32_t localOffset = cd.localHeaderOffset;
        if (localOffset + sizeof(ZipLocalFileHeader) > len) continue;
        ZipLocalFileHeader lh;
        memcpy(&lh, bytes + localOffset, sizeof(lh));
        if (lh.signature != ZIP_LOCAL_SIG) continue;

        uint32_t dataOffset = localOffset + sizeof(lh) + lh.filenameLen + lh.extraLen;

        uint32_t compSize = cd.compressedSize;
        uint32_t uncompSize = cd.uncompressedSize;

        // Handle data descriptor (bit 3 of flags)
        if (lh.compressedSize == 0 && (lh.flags & 0x08)) {
            compSize = cd.compressedSize;
            uncompSize = cd.uncompressedSize;
        } else if (lh.compressedSize > 0) {
            compSize = lh.compressedSize;
            uncompSize = lh.uncompressedSize;
        }

        if (dataOffset + compSize > len) continue;

        NSData *fileData;
        if (cd.compression == 0) {
            // Stored
            fileData = [NSData dataWithBytes:bytes + dataOffset length:uncompSize];
        } else if (cd.compression == 8) {
            // Deflate
            NSMutableData *inflated = [NSMutableData dataWithLength:uncompSize];
            z_stream strm = {0};
            strm.next_in = (Bytef *)(bytes + dataOffset);
            strm.avail_in = compSize;
            strm.next_out = inflated.mutableBytes;
            strm.avail_out = uncompSize;
            if (inflateInit2(&strm, -MAX_WBITS) == Z_OK) {
                inflate(&strm, Z_FINISH);
                inflateEnd(&strm);
            }
            fileData = inflated;
        } else {
            continue;
        }

        [fileData writeToFile:outPath atomically:YES];
    }

    return YES;
}

+ (BOOL)createZipAtPath:(NSString *)zipPath fromDirectory:(NSString *)sourceDir error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableData *zipData = [NSMutableData data];
    NSMutableArray *centralEntries = [NSMutableArray array];

    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:sourceDir];
    NSString *relativePath;

    while ((relativePath = [enumerator nextObject])) {
        NSString *fullPath = [sourceDir stringByAppendingPathComponent:relativePath];
        BOOL isDir = NO;
        [fm fileExistsAtPath:fullPath isDirectory:&isDir];

        NSString *zipEntryName = relativePath;
        if (isDir) {
            zipEntryName = [relativePath stringByAppendingString:@"/"];
        }

        NSData *nameData = [zipEntryName dataUsingEncoding:NSUTF8StringEncoding];
        NSData *fileData = isDir ? [NSData data] : [NSData dataWithContentsOfFile:fullPath];
        if (!fileData) fileData = [NSData data];

        // Compress the data
        NSData *compressedData;
        uint16_t compressionMethod;
        if (isDir || fileData.length == 0) {
            compressedData = fileData;
            compressionMethod = 0; // stored
        } else {
            uLongf compLen = compressBound((uLong)fileData.length);
            NSMutableData *comp = [NSMutableData dataWithLength:compLen];

            z_stream strm = {0};
            strm.next_in = (Bytef *)fileData.bytes;
            strm.avail_in = (uInt)fileData.length;
            strm.next_out = comp.mutableBytes;
            strm.avail_out = (uInt)compLen;

            if (deflateInit2(&strm, Z_DEFAULT_COMPRESSION, Z_DEFLATED, -MAX_WBITS, 8, Z_DEFAULT_STRATEGY) == Z_OK) {
                deflate(&strm, Z_FINISH);
                deflateEnd(&strm);
                [comp setLength:strm.total_out];
                compressedData = comp;
                compressionMethod = 8; // deflate
            } else {
                compressedData = fileData;
                compressionMethod = 0;
            }
        }

        uint32_t fileCrc = (uint32_t)crc32(0, fileData.bytes, (uInt)fileData.length);

        uint32_t localOffset = (uint32_t)zipData.length;

        // Write local file header
        ZipLocalFileHeader lh = {0};
        lh.signature = ZIP_LOCAL_SIG;
        lh.versionNeeded = 20;
        lh.compression = compressionMethod;
        lh.crc32 = fileCrc;
        lh.compressedSize = (uint32_t)compressedData.length;
        lh.uncompressedSize = (uint32_t)fileData.length;
        lh.filenameLen = (uint16_t)nameData.length;

        [zipData appendBytes:&lh length:sizeof(lh)];
        [zipData appendData:nameData];
        [zipData appendData:compressedData];

        // Store central directory entry info
        NSMutableData *cdEntry = [NSMutableData data];
        ZipCentralDirEntry cd = {0};
        cd.signature = ZIP_CENTRAL_SIG;
        cd.versionMadeBy = 20;
        cd.versionNeeded = 20;
        cd.compression = compressionMethod;
        cd.crc32 = fileCrc;
        cd.compressedSize = (uint32_t)compressedData.length;
        cd.uncompressedSize = (uint32_t)fileData.length;
        cd.filenameLen = (uint16_t)nameData.length;
        cd.externalAttr = isDir ? 0x10 : 0;
        cd.localHeaderOffset = localOffset;

        [cdEntry appendBytes:&cd length:sizeof(cd)];
        [cdEntry appendData:nameData];
        [centralEntries addObject:cdEntry];
    }

    uint32_t cdOffset = (uint32_t)zipData.length;
    uint32_t cdSize = 0;
    for (NSData *entry in centralEntries) {
        [zipData appendData:entry];
        cdSize += entry.length;
    }

    ZipEndOfCentralDir eocd = {0};
    eocd.signature = ZIP_EOCD_SIG;
    eocd.centralDirRecordsOnDisk = (uint16_t)centralEntries.count;
    eocd.centralDirRecordsTotal = (uint16_t)centralEntries.count;
    eocd.centralDirSize = cdSize;
    eocd.centralDirOffset = cdOffset;

    [zipData appendBytes:&eocd length:sizeof(eocd)];

    return [zipData writeToFile:zipPath options:NSDataWritingAtomic error:error];
}

@end
