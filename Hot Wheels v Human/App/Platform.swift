//
//  Platform.swift
//  Hot Wheels v Human
//
//  The one place where #if os(tvOS) is expected to be dense.
//

enum Platform {
    #if os(tvOS)
    static let isTV = true
    #else
    static let isTV = false
    #endif
}
