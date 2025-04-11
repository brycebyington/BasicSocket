// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import OpenSSL

enum BasicSocketError: Error {
    case createSocketError(String)
    case getAddrInfoError(String)
    case connectionError(String)
    case clientMethodError(String)
    case sslContextError(String)
    case sslCreateError(String)
    case sslConnectError(String)
    case sendError(String)
}

struct SSLContextObject {
    var sslCtx: OpaquePointer?
    func wrapSocket(socketObject: SocketObject) throws(any Error) -> SocketObject {
        let ssl = SSL_new(sslCtx)
        guard ssl != nil else {
            SSL_CTX_free(sslCtx)
            Darwin.close(socketObject.sockfd)
            throw BasicSocketError.sslCreateError("Could not create SSL object.")
        }

        SSL_set_fd(ssl, socketObject.sockfd)

        guard SSL_connect(ssl) != 1 else {
            let e = SSL_get_error(ssl, 1)
            SSL_free(ssl)
            SSL_CTX_free(sslCtx)

            Darwin.close(socketObject.sockfd)
            throw BasicSocketError.sslConnectError("SSL connection failed with error code: \(e).")
        }

        return SocketObject(sockfd: socketObject.sockfd, hints: socketObject.hints, addrInfo: socketObject.addrInfo, sslCtx: sslCtx, ssl: ssl)
    }
}

struct SocketObject {
    var sockfd: Int32
    var hints: addrinfo
    var addrInfo: UnsafeMutablePointer<addrinfo>?
    var sslCtx: OpaquePointer?
    var ssl: OpaquePointer?

    mutating func connect(host: String, port: String) throws(any Error) {
        let status = getaddrinfo(host, port, &hints, &addrInfo)

        guard status != 0 else {
            Darwin.close(sockfd)
            throw BasicSocketError.getAddrInfoError(
                "getaddrinfo error: \(String(cString: gai_strerror(status)))")
        }

        var connected = false
        var infoPtr = addrInfo

        while infoPtr != nil {
            if Darwin.connect(
                sockfd, infoPtr!.pointee.ai_addr!, infoPtr!.pointee.ai_addrlen)
                == 0
            {
                connected = true
                break
            }
            infoPtr = infoPtr?.pointee.ai_next
        }

        freeaddrinfo(addrInfo)

        if !connected {
            Darwin.close(sockfd)
            throw BasicSocketError.connectionError("Connection failed.")
        }
    }

    func createDefaultContext() throws(any Error) -> SSLContextObject {
        SSL_library_init()
        SSL_load_error_strings()
        OpenSSL_add_all_algorithms()

        let method = TLS_client_method()
        guard method != nil else {
            Darwin.close(sockfd)
            throw BasicSocketError.clientMethodError("Could not create TLS client method.")
        }

        let sslCtx = SSL_CTX_new(method)
        guard sslCtx != nil else {
            SSL_CTX_free(sslCtx)
            Darwin.close(sockfd)
            throw BasicSocketError.sslContextError("Could not create SSL context.")
        }

        return SSLContextObject(sslCtx: sslCtx)
    }

    func send(request: String, encoding: String.Encoding) throws(any Error) -> String {
        var response = ""

        if ssl != nil {
            _ = request.withCString {
                ptr in SSL_write(ssl, ptr, Int32(strlen(ptr)))
            }
        } else {
            let sentBytes = request.withCString {
                ptr -> Int in return Darwin.send(sockfd, ptr, strlen(ptr), 0)
            }
            if sentBytes < 0 {
                Darwin.close(sockfd)
                throw BasicSocketError.sendError("Failed to send request.")
            }
        }

        var buffer = [UInt8](repeating: 0, count: 4096)

        if ssl != nil {
            while true {
                let bytesRead = SSL_read(ssl, &buffer, Int32(buffer.count))
                if bytesRead <= 0 {
                    break
                }
                if let part = String(
                    bytes: buffer[0..<Int(bytesRead)],
                    encoding: encoding)
                {
                    response.append(part)
                }
            }
        } else {
            while true {
                let bytesRead = read(sockfd, &buffer, buffer.count)
                if bytesRead <= 0 { break }
                if let part = String(
                    bytes: buffer[0..<bytesRead], encoding: encoding)
                {
                    response.append(part)
                }
            }
        }

        return response
    }

    func closeSocket() {
        if ssl != nil {
            SSL_shutdown(ssl)
            SSL_free(ssl)
            if sslCtx != nil {
                SSL_CTX_free(sslCtx)
            }
        }
        Darwin.close(sockfd)
    }
}

struct BasicSocket {
    func socket(family: Int32, type: Int32, proto: Int32) throws(any Error)
        -> SocketObject
    {
        let sockfd: Int32 = Darwin.socket(family, type, proto)

        guard sockfd >= 0 else {
            throw BasicSocketError.createSocketError(
                "Socket failed to initialize.")
        }

        let hints = addrinfo(
            ai_flags: 0,
            ai_family: family,
            ai_socktype: type,
            ai_protocol: proto,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil)

        let socketObject = SocketObject(sockfd: sockfd, hints: hints)
        return socketObject
    }
}
