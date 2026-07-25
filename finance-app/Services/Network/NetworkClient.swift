import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case httpError(statusCode: Int, message: String)
    case serializationError(Error)
    case deserializationError(Error)
    case noData
    case unauthorized
    case notFound
    case conflict
    case networkUnavailable(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Некорректный URL"
        case .httpError(let statusCode, let message):
            return "Ошибка сервера (\(statusCode)): \(message)"
        case .serializationError:
            return "Ошибка подготовки запроса"
        case .deserializationError:
            return "Ошибка обработки ответа сервера"
        case .noData:
            return "Нет данных от сервера"
        case .unauthorized:
            return "Не удалось авторизоваться"
        case .notFound:
            return "Данные не найдены"
        case .conflict:
            return "Конфликт данных"
        case .networkUnavailable:
            return "Нет подключения к сети"
        }
    }
}

final class NetworkClient {
    static let shared = NetworkClient()
    
    private let baseURL = "https://shmr-finance.ru/api/v1"
    private let token: String
    private let session: URLSession
    let encoder: JSONEncoder
    let decoder: JSONDecoder
    
    private init() {
        self.token = "23708b59ca865cb482ce0552c1cae0cf"
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
        
        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }
    
    func get<T: Decodable>(
        endpoint: String,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        try await request(endpoint: endpoint, method: .get, body: nil as String?, queryItems: queryItems)
    }
    
    func request<T: Decodable, R: Encodable>(
        endpoint: String,
        method: HTTPMethod,
        body: R? = nil,
        queryItems: [URLQueryItem]? = nil
    ) async throws -> T {
        let urlRequest = try buildRequest(endpoint: endpoint, method: method, body: body, queryItems: queryItems)
        let (data, response) = try await performRequest(urlRequest)
        return try decode(T.self, from: data, response: response)
    }
    
    func delete(endpoint: String, queryItems: [URLQueryItem]? = nil) async throws {
        let urlRequest = try buildRequest(endpoint: endpoint, method: .delete, body: nil as String?, queryItems: queryItems)
        let (data, response) = try await performRequest(urlRequest)
        try validateResponse(response, data: data)
    }
    
    private func buildRequest<R: Encodable>(
        endpoint: String,
        method: HTTPMethod,
        body: R?,
        queryItems: [URLQueryItem]?
    ) throws -> URLRequest {
        var components = URLComponents(string: baseURL + endpoint)
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let body = body {
            do {
                let data = try encoder.encode(body)
                request.httpBody = data
                
                #if DEBUG
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📤 Request \(method.rawValue) \(endpoint):")
                    print(jsonString)
                }
                #endif
            } catch {
                throw NetworkError.serializationError(error)
            }
        }
        
        return request
    }
    
    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError where error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
            throw NetworkError.networkUnavailable(error)
        } catch {
            throw NetworkError.networkUnavailable(error)
        }
    }
    
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.httpError(statusCode: 0, message: "Некорректный ответ")
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw NetworkError.unauthorized
        case 404:
            throw NetworkError.notFound
        case 409:
            throw NetworkError.conflict
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            #if DEBUG
            print("❌ HTTP Error \(httpResponse.statusCode):")
            print(message)
            #endif
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, message: message)
        }
    }
    
    private func decode<T: Decodable>(_ type: T.Type, from data: Data, response: URLResponse) throws -> T {
        #if DEBUG
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📥 Response:")
            print(jsonString)
        }
        #endif
        
        try validateResponse(response, data: data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.deserializationError(error)
        }
    }
}
