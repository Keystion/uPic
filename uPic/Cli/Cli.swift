//
//  uPicCli.swift
//  uPic
//
//  Created by Svend Jin on 2019/12/26.
//  Copyright © 2019 Svend Jin. All rights reserved.
//

import Foundation
import Cocoa

enum UploadSourceType {
    case normal
    case cli
}

class Cli {
    public static var shared = Cli()
    
    private var cliKit: CommandLineKit!
    private var upload: MultiStringOption!
    private var output: StringOption!
    private var slient: BoolOption!
    
    private var allPathList: [String] = []
    private var allDataList: [Any] = []
    private var progress: Int = 0
    
    private var resultUrls: [String] = []
    
    func handleCommandLine() -> Bool {
        // handle arguments
        let arguments = clearMacosAppTakeParameters()
        // let arguments = ["uPic", "-u", "/Users/svend/Desktop/uPicv0.15.3.png", "/Users/svend/Desktop/1111.png", "/Users/svend/Desktop", "http://qiniu.svend.cc/uPic/2019%2012%2026g8WCtu.png", "-s"]
//        let arguments = ["uPic", "-h"]
        guard arguments.count > 1 else { return false }
        
        cliKit = CommandLineKit(arguments: arguments)
        
        allPathList = []
        allDataList = []
        resultUrls = []
        
        upload = MultiStringOption(shortFlag: "u", longFlag: "upload", helpMessage: "Path and URL of the file to upload".localized)
        output = StringOption(shortFlag: "o", longFlag: "output", helpMessage: "Output url format".localized)
        slient = BoolOption(shortFlag: "s", longFlag: "slient", helpMessage: "Turn off error message output".localized)
        let help = BoolOption(shortFlag: "h", longFlag: "help", helpMessage: "Prints a help message".localized)
        cliKit.addOptions(upload, output, slient, help)
        do {
            try cliKit.parse()
        } catch {
            cliKit.printUsage(error)
            exit(EX_USAGE)
        }
        
        if let paths = upload.value {
            startUpload(paths)
        } else if help.value {
            cliKit.printUsage()
            exit(EX_USAGE)
        }
        
        return true
    }
    
    private func clearMacosAppTakeParameters() -> [String] {
        let arguments = ProcessInfo.processInfo.arguments
        var cleardArguments: [String]  = []
        
        var dropNextArg = false
        for arg in arguments {
          if dropNextArg {
            dropNextArg = false
            continue
          }
          if arg.hasPrefix("-NS") {
            dropNextArg = true
          } else {
            cleardArguments.append(arg)
          }
        }
        
        return cleardArguments
    }
    
}

// MARK: - Upload
extension Cli {
    /// start upload
    /// - Parameter paths: file paths or URLs
    private func startUpload(_ paths: [String]) {
        allPathList = paths
        
        for path in paths {
            let decodePath = path.urlDecoded()
            if decodePath.isAbsolutePath && FileManager.fileIsExists(path: decodePath) {
                allDataList.append(URL(fileURLWithPath: decodePath))
            } else if let fileUrl = URL(string: path), let data = try? Data(contentsOf: fileUrl)  {
                allDataList.append(data)
            } else {
                allDataList.append(path)
            }
        }
        
        var totalPathsCount = "Total paths count".localized
        totalPathsCount = totalPathsCount.replacingOccurrences(of: "{count}", with: "\(allDataList.count)")
        Console.write(totalPathsCount)
        
        // start upload
        Console.write("Uploading ...")
        (NSApplication.shared.delegate as? AppDelegate)?.uploadFiles(allDataList, .cli)
    }
    
    
    /// Upload progress
    /// - Parameter url: current url
    func uploadProgress(_ url: String) {
        let outputType = OutputType(value: output?.value)
        resultUrls.append(outputType.formatUrl(url.urlEncoded()))
        progress += 1
        Console.write("Uploading \(progress)/\(allDataList.count)")
    }
    
    /// Upload error
    /// - Parameter errorMessage
    func uploadError(_ errorMessage: String? = nil) {
        if slient.value {
            resultUrls.append(allPathList[progress])
        } else {
            resultUrls.append(errorMessage ?? "Invalid file path".localized)
        }
        progress += 1
        Console.write("Uploading \(progress)/\(allDataList.count)")
    }
    
    
    /// all task was uploaded
    func uploadDone() {
        Console.write("Output URL:")
        
        Console.write(resultUrls.joined(separator: "\n"))

        exit(EX_OK)
    }
}
