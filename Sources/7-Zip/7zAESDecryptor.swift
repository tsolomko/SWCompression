// Copyright (c) 2026 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import CommonCrypto
import Foundation

/// AES-256-CBC decryptor for 7-Zip encrypted streams.
///
/// 7-Zip uses coder ID `[0x06, 0xF1, 0x07, 0x01]` for AES-256 + SHA-256 encryption.
///
/// Properties format (from 7-Zip source `7zAes.cpp` SetDecoderProperties2):
///   - Byte 0 (b0):
///     - bits 0-5: numCyclesPower (SHA-256 iterations = 2^numCyclesPower)
///     - bit 6: contributes +1 to ivSize
///     - bit 7: contributes +1 to saltSize
///   - Byte 1 (b1, present if b0 bits 6-7 != 0):
///     - upper nibble (b1 >> 4): adds to saltSize
///     - lower nibble (b1 & 0x0F): adds to ivSize
///   - saltSize = ((b0 >> 7) & 1) + (b1 >> 4)
///   - ivSize   = ((b0 >> 6) & 1) + (b1 & 0x0F)
///   - Remaining bytes: salt (saltSize bytes) + IV (ivSize bytes)
///
/// Key derivation (from CalcKey):
///   buf = salt + password_as_raw_bytes + 8_zero_bytes (counter placeholder)
///   For each round (0..<2^numCyclesPower):
///     write round counter as UInt32 LE at buf[saltSize+passwordSize..saltSize+passwordSize+4]
///     (upper 4 bytes of 8-byte counter remain zero since numRounds fits in UInt32)
///     SHA256.update(buf)
///   key = SHA256.finalize()
enum SevenZipAESDecryptor {

    /// Decrypt data using 7z AES-256-CBC with the given password and coder properties.
    static func decrypt(data: Data, properties: [UInt8], password: String) throws -> Data {
        guard !properties.isEmpty else {
            throw SevenZipError.internalStructureError
        }

        // Parse properties - matching 7-Zip's SetDecoderProperties2
        let b0 = properties[0]
        let numCyclesPower = Int(b0 & 0x3F)

        var saltSize = 0
        var ivSize = 0

        if (b0 & 0xC0) != 0 {
            // Has salt/IV size info
            guard properties.count > 1 else {
                throw SevenZipError.internalStructureError
            }
            let b1 = properties[1]
            saltSize = Int((b0 >> 7) & 1) + Int(b1 >> 4)
            ivSize = Int((b0 >> 6) & 1) + Int(b1 & 0x0F)

            guard properties.count == 2 + saltSize + ivSize else {
                throw SevenZipError.internalStructureError
            }
        }

        // Extract salt
        var salt = Data()
        if saltSize > 0 {
            salt = Data(properties[2..<(2 + saltSize)])
        }

        // Extract IV (pad to 16 bytes with zeros)
        var iv = Data(count: 16)
        if ivSize > 0 {
            let ivStart = 2 + saltSize
            for i in 0..<min(ivSize, 16) {
                iv[i] = properties[ivStart + i]
            }
        }

        // Derive key using SHA-256 (matching 7-Zip's CalcKey)
        let key = try deriveKey(password: password, salt: salt, numCyclesPower: numCyclesPower)

        // Decrypt using AES-256-CBC
        return try aes256CBCDecrypt(data: data, key: key, iv: iv)
    }

    /// Derive a 32-byte AES-256 key from a password using 7z's SHA-256 key derivation.
    ///
    /// Matches 7-Zip's CalcKey() in 7zAes.cpp:
    ///   buf = salt + password_raw_bytes + 8_byte_counter
    ///   for round in 0..<(2^numCyclesPower):
    ///     store round as LE UInt32 at counter position (last 8 bytes, upper 4 stay zero)
    ///     sha256.update(buf)
    ///   key = sha256.finalize()
    private static func deriveKey(password: String, salt: Data, numCyclesPower: Int) throws -> Data
    {
        if numCyclesPower == 0x3F {
            // Special case: direct key from salt + password (no hashing)
            var key = Data(count: 32)
            var pos = 0
            for i in 0..<salt.count where pos < 32 {
                key[pos] = salt[i]
                pos += 1
            }
            // Password is raw bytes (UTF-16LE in 7-Zip's case via CryptoSetPassword)
            if let pwdData = password.data(using: .utf16LittleEndian) {
                for i in 0..<pwdData.count where pos < 32 {
                    key[pos] = pwdData[i]
                    pos += 1
                }
            }
            return key
        }

        // 7-Zip passes password as raw UTF-16LE bytes via CryptoSetPassword
        guard let passwordBytes = password.data(using: .utf16LittleEndian) else {
            throw SevenZipError.internalStructureError
        }

        // Build the base buffer: salt + password + 8 zero bytes (counter)
        let bufSize = salt.count + passwordBytes.count + 8
        var buf = Data(count: bufSize)
        buf.replaceSubrange(0..<salt.count, with: salt)
        buf.replaceSubrange(salt.count..<salt.count + passwordBytes.count, with: passwordBytes)
        // Last 8 bytes are the counter, initialized to 0

        let counterOffset = salt.count + passwordBytes.count
        let numRounds: UInt32 = 1 << UInt32(numCyclesPower)

        var context = CC_SHA256_CTX()
        CC_SHA256_Init(&context)

        for round: UInt32 in 0..<numRounds {
            // Write round counter as little-endian UInt32 at counterOffset
            // (upper 4 bytes of the 8-byte field stay zero, as in 7-Zip source)
            buf[counterOffset + 0] = UInt8(round & 0xFF)
            buf[counterOffset + 1] = UInt8((round >> 8) & 0xFF)
            buf[counterOffset + 2] = UInt8((round >> 16) & 0xFF)
            buf[counterOffset + 3] = UInt8((round >> 24) & 0xFF)

            buf.withUnsafeBytes { ptr in
                _ = CC_SHA256_Update(&context, ptr.baseAddress, CC_LONG(bufSize))
            }
        }

        var hash = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        hash.withUnsafeMutableBytes { ptr in
            _ = CC_SHA256_Final(ptr.bindMemory(to: UInt8.self).baseAddress, &context)
        }

        return hash
    }

    /// AES-256-CBC decryption using CommonCrypto.
    private static func aes256CBCDecrypt(data: Data, key: Data, iv: Data) throws -> Data {
        let outputLength = data.count + kCCBlockSizeAES128
        var outputData = Data(count: outputLength)
        var numBytesDecrypted: size_t = 0

        let status = outputData.withUnsafeMutableBytes { outputPtr in
            data.withUnsafeBytes { dataPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(0),  // No padding — 7z handles padding via data trimming
                            keyPtr.baseAddress, key.count,
                            ivPtr.baseAddress,
                            dataPtr.baseAddress, data.count,
                            outputPtr.baseAddress, outputLength,
                            &numBytesDecrypted
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else {
            throw SevenZipError.internalStructureError
        }

        outputData.count = numBytesDecrypted
        return outputData
    }
}
