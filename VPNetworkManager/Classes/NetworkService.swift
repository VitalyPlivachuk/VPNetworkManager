//
//  NetworkService.swift
//  Wallpapers
//
//  Created by admin on 12/4/18.
//  Copyright © 2018 Adwool. All rights reserved.
//

import Foundation

class NetworkService: NetworkServiceProtocol {
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder
    private let downloadService: DownloadService
    
    enum HttpMethod: String {
        case post = "POST"
        case get = "GET"
    }
    
    enum NetworkServiceError: LocalizedError {
        case unknown
    }
    
    enum LoadingState {
        case completed
        case loading(progress: Double)
    }
    
    init(downloadService: DownloadService) {
        self.jsonDecoder = JSONDecoder()
        self.jsonEncoder = JSONEncoder()
        self.downloadService = downloadService
    }
    
    private func buildRequest<BodyType: Encodable>(for url: URL, headerFields: HeaderFields?, method: HttpMethod, body: BodyType) throws -> URLRequest {
        let data = try jsonEncoder.encode(body)
        var request = URLRequest(url: url)
        headerFields?.forEach {request.addValue($0.value, forHTTPHeaderField: $0.key)}
        request.httpMethod = method.rawValue
        request.httpBody = data
        return request
    }
    
    private func buildRequest(for url: URL, headerFields: HeaderFields?, method: HttpMethod) -> URLRequest {
        var request = URLRequest(url: url)
        headerFields?.forEach {request.addValue($0.value, forHTTPHeaderField: $0.key)}
        request.httpMethod = method.rawValue
        return request
    }
    
    private func buildRequest(for url: URL, headerFields: HeaderFields?, body: [String: String], method: HttpMethod) -> URLRequest {
        var request = URLRequest(url: url)
        let data = body
            .map {"\($0)=\($1)"}
            .joined(separator: "&")
            .data(using: .utf8)
        headerFields?.forEach {request.addValue($0.value, forHTTPHeaderField: $0.key)}
        request.httpMethod = method.rawValue
        request.httpBody = data
        return request
    }
    
    private func parse<T: Decodable>(result: Result<Data>) -> Result<T> {
        do {
            let data = try result.dematerialize()
            let object = try jsonDecoder.decode(T.self, from: data)
            return .success(object)
        } catch let error {
            return .failure(error)
        }
    }
    
    // MARK: - Get
    func performGetRequest(url: URL, priority: Float, headerFields: HeaderFields?, progress: ProgressCallback?, completion: @escaping (Result<Data>) -> Void) {
        let request = buildRequest(for: url, headerFields: headerFields, method: HttpMethod.get)
        var downloadTask = downloadService.download(request: request, priority: priority)
        downloadTask.progressHandler = progress
        downloadTask.completionHandlers.append(completion)
        downloadTask.resume()
        return
    }
    
    func performGetRequest<ResponseType: Decodable>(url: URL, priority: Float, headerFields: HeaderFields?, progress: ProgressCallback?, completion: @escaping (Result<ResponseType>) -> Void) {
        performGetRequest(url: url, priority: priority, headerFields: headerFields, progress: progress) { [weak self] in
            guard let result: Result<ResponseType> = self?.parse(result: $0) else {
                completion(.failure(NetworkServiceError.unknown))
                return
            }
            completion(result)
        }
    }
    
    // MARK: - Post
    func performPostRequest<RequestType: Encodable>(url: URL, priority: Float, headerFields: HeaderFields?, body: RequestType, progress: ProgressCallback?, completion: @escaping (Result<Data>) -> Void) {
        do {
            let request = try buildRequest(for: url, headerFields: headerFields, method: .post, body: body)
            var downloadTask = downloadService.download(request: request, priority: priority)
            downloadTask.progressHandler = progress
            downloadTask.completionHandlers.append(completion)
            downloadTask.resume()
        } catch let error {
            completion(.failure(error))
        }
    }
    
    func performPostRequest(url: URL, priority: Float, headerFields: HeaderFields?, progress: ProgressCallback?, completion: @escaping (Result<Data>) -> Void) {
        let request = buildRequest(for: url, headerFields: headerFields, method: .post)
        var downloadTask = downloadService.download(request: request, priority: priority)
        downloadTask.progressHandler = progress
        downloadTask.completionHandlers.append(completion)
        downloadTask.resume()
    }
    
    func performPostRequest<RequestType: Encodable, ResponseType: Decodable>(url: URL, priority: Float, headerFields: HeaderFields?, body: RequestType, progress: ProgressCallback?, completion: @escaping (Result<ResponseType>) -> Void) {
        performPostRequest(url: url, priority: priority, headerFields: headerFields, body: body, progress: progress) {[weak self] in
            guard let result: Result<ResponseType> = self?.parse(result: $0) else {
                completion(.failure(NetworkServiceError.unknown))
                return
            }
            completion(result)
        }
    }
    
    func performPostRequest<ResponseType: Decodable>(url: URL, priority: Float, headerFields: HeaderFields?, progress: ProgressCallback?, completion: @escaping (Result<ResponseType>) -> Void) {
        performPostRequest(url: url, priority: priority, headerFields: headerFields, progress: progress) {[weak self] in
            guard let result: Result<ResponseType> = self?.parse(result: $0) else {
                completion(.failure(NetworkServiceError.unknown))
                return
            }
            completion(result)
        }
    }
    
    func performPostRequest(url: URL, priority: Float, headerFields: HeaderFields?, body: [String: String], completion: @escaping (Result<Data>) -> Void) {
        let request = buildRequest(for: url, headerFields: headerFields, body: body, method: .post)
        var downloadTask = downloadService.download(request: request, priority: priority)
        downloadTask.completionHandlers.append(completion)
        downloadTask.resume()
    }
    
    func set(priority: Float, forTaskWith url: URL) {
        downloadService.set(priority: priority, forTaskWith: url)
    }
}

protocol NetworkServiceProtocol {
    typealias ProgressCallback = (Double) -> Void
    typealias HeaderFields = [String: String]
    
    //MARK: - GET
    func performGetRequest(url: URL,
                           priority: Float,
                           headerFields: HeaderFields?,
                           progress: ProgressCallback?,
                           completion: @escaping (Result<Data>) -> Void)
    
    func performGetRequest<ResponseType: Decodable>(url: URL,
                                                    priority: Float,
                                                    headerFields: HeaderFields?,
                                                    progress: ProgressCallback?,
                                                    completion: @escaping (Result<ResponseType>) -> Void)
    
    //MARK: - POST
    func performPostRequest<RequestType: Encodable>(url: URL,
                                                    priority: Float,
                                                    headerFields: HeaderFields?,
                                                    body: RequestType,
                                                    progress: ProgressCallback?,
                                                    completion: @escaping (Result<Data>) -> Void)
    
    func performPostRequest(url: URL,
                            priority: Float,
                            headerFields: HeaderFields?,
                            body: [String: String],
                            completion: @escaping (Result<Data>) -> Void)
    
    func performPostRequest<RequestType: Encodable, ResponseType: Decodable>(url: URL,
                                                                             priority: Float,
                                                                             headerFields: HeaderFields?,
                                                                             body: RequestType,
                                                                             progress: ProgressCallback?,
                                                                             completion: @escaping (Result<ResponseType>) -> Void)
    
    func performPostRequest(url: URL,
                            priority: Float,
                            headerFields: HeaderFields?,
                            progress: ProgressCallback?,
                            completion: @escaping (Result<Data>) -> Void)
    
    func performPostRequest<ResponseType: Decodable>(url: URL,
                                                     priority: Float,
                                                     headerFields: HeaderFields?,
                                                     progress: ProgressCallback?,
                                                     completion: @escaping (Result<ResponseType>) -> Void)
    
    func set(priority: Float, forTaskWith url: URL)
}
