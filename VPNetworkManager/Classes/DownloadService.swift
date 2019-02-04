//
//  DownloadService.swift
//  Wallpapers
//
//  Created by admin on 12/4/18.
//  Copyright © 2018 Adwool. All rights reserved.
//

import UIKit

class DownloadService: NSObject {
    private var session: URLSession!
    private let delegateQueue: OperationQueue
    private var downloadTasks: SynchronizedArray<GenericDownloadTask> = .init()
    
    init(config: URLSessionConfiguration) {
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        self.delegateQueue = operationQueue
        
        super.init()
        
        self.session = URLSession(configuration: config,
                                  delegate: self,
                                  delegateQueue: delegateQueue)
    }
    
    func download(request: URLRequest, priority: Float) -> DownloadTask {
        indicate(loading: true)
        if let downloadTask = downloadTasks.first(where: {
            guard let url = request.url else {return false}
            return $0.task.currentRequest?.url == url
        }) {
            downloadTask.task.priority = priority
            return downloadTask
        }
        
        let task = session.dataTask(with: request)
        task.priority = priority
        let downloadTask = GenericDownloadTask(task: task)
        downloadTasks.append(downloadTask)
        return downloadTask
    }
    
    func set(priority: Float, forTaskWith url: URL) {
        if let downloadTask = downloadTasks.first(where: {
            return $0.task.currentRequest?.url == url
        }) {
            downloadTask.task.priority = priority
        }
    }
    
    private func indicate(loading: Bool) {
        DispatchQueue.main.async {
            UIApplication.shared.isNetworkActivityIndicatorVisible = loading
        }
    }
}

extension DownloadService: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        
        guard let task = downloadTasks.first(where: { $0.task == dataTask }) else {
            completionHandler(.cancel)
            return
        }
        task.expectedContentLength = response.expectedContentLength
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let task = downloadTasks.first(where: { $0.task == dataTask }) else {
            return
        }
        task.buffer.append(data)
        let percentageDownloaded = Double(task.buffer.count) / Double(task.expectedContentLength)
        DispatchQueue.main.async {
            task.progressHandler?(percentageDownloaded)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        downloadTasks.remove(where: { $0.task == task }) {[weak self] task in
            if let self = self, self.downloadTasks.isEmpty { 
                self.indicate(loading: false)
            }
            
            DispatchQueue.main.async {
                if let e = error {
                    task.completionHandlers.forEach {$0(.failure(e))}
                } else {
                    task.completionHandlers.forEach {$0(.success(task.buffer))}
                }
            }
        }
    }
}

protocol DownloadTask {
    typealias DownloadTaskCompletion = ((Result<Data>) -> Void)
    
    var completionHandlers: [DownloadTaskCompletion] { get set }
    var progressHandler: ((Double) -> Void)? { get set }
    
    func resume()
    func suspend()
    func cancel()
}

class GenericDownloadTask: DownloadTask {
    
    var completionHandlers: [DownloadTaskCompletion] = []
    var progressHandler: ((Double) -> Void)?
    
    private(set) var task: URLSessionDataTask
    var expectedContentLength: Int64 = 0
    var buffer = Data()
    
    init(task: URLSessionDataTask) {
        self.task = task
    }
    
    deinit {
        print("GenericDownloadTask deinit: \(task.originalRequest?.url?.absoluteString ?? "")")
    }
    
}

extension GenericDownloadTask {
    
    func resume() {
        task.resume()
    }
    
    func suspend() {
        task.suspend()
    }
    
    func cancel() {
        task.cancel()
    }
}
