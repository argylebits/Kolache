//  Kolache.swift
//  Kolache
//
//  Created by Argyle Bits LLC

import ArgumentParser

@main
struct Kolache: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A Swift command-line tool."
    )

    func run() throws {
        print("Hello from Kolache!")
    }
}