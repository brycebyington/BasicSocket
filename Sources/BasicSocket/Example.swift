//
//  Example.swift
//  BasicSocket
//
//  Created by Bryce Byington on 4/10/25.
//

import Foundation

func example() {
    var s = try! BasicSocket().createSocket(
        family: AF_INET, type: SOCK_STREAM, proto: IPPROTO_TCP)

    try! s.connectSocket(host: "example.org", port: "443")

    let ctx = try! s.createDefaultContext()

    s = try! ctx.wrapSocket(socketObject: s)

    let response = try! s.sendRequest(request: "GET / HTTP/1.1\r\nHost: example.org\r\nConnection: close\r\nUser-Agent: my-browser\r\n\r\n", encoding: String.Encoding.utf8)

    print(response)

    s.closeSocket()
}
