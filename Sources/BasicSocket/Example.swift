//
//  Example.swift
//  BasicSocket
//
//  Created by Bryce Byington on 4/10/25.
//

import Foundation

func example() {
    var s = try! BasicSocket().socket(
        family: AF_INET, type: SOCK_STREAM, proto: IPPROTO_TCP)

    try! s.connect(host: "google.com", port: "443")

    let ctx = try! s.createDefaultContext()

    s = try! ctx.wrapSocket(socketObject: s)

    let response = try! s.send(request: "GET / HTTP/1.1\r\n\r\n", encoding: .utf8)

    print(response)

    s.closeSocket()
}
