// Models/StravaConnection.swift
// Persists the Strava OAuth token and athlete profile info.
// Sensitive tokens should ideally be stored in Keychain in production;
// this model stores non-sensitive metadata and a reference key.

import Foundation
import SwiftData

@Model
final class StravaConnection {
    var id: UUID
    var athleteId: Int
    var athleteName: String
    var athleteUsername: String?
    var profilePictureURL: String?
    var isConnected: Bool
    var lastSyncedAt: Date?
    /// Keychain key under which the access token is stored.
    /// The actual token lives in Keychain, not in SwiftData.
    var keychainTokenKey: String

    init(
        athleteId: Int,
        athleteName: String,
        athleteUsername: String? = nil,
        profilePictureURL: String? = nil
    ) {
        self.id = UUID()
        self.athleteId = athleteId
        self.athleteName = athleteName
        self.athleteUsername = athleteUsername
        self.profilePictureURL = profilePictureURL
        self.isConnected = true
        self.lastSyncedAt = nil
        self.keychainTokenKey = "strava_token_\(athleteId)"
    }
}

// MARK: - Strava API DTOs (Decodable response models)

/// Athlete summary returned by Strava's /athlete endpoint.
struct StravaAthlete: Decodable {
    let id: Int
    let firstname: String
    let lastname: String
    let username: String?
    let profile: String?    // URL to profile picture
    let city: String?
    let state: String?

    var fullName: String { "\(firstname) \(lastname)" }
}

/// Activity summary returned by Strava's /athlete/activities endpoint.
struct StravaActivity: Decodable, Identifiable {
    let id: Int
    let name: String
    let type: String
    let sportType: String
    let distance: Double            // meters
    let movingTime: Int             // seconds
    let elapsedTime: Int            // seconds
    let totalElevationGain: Double  // meters
    let startDate: Date
    let averageHeartrate: Double?
    let maxHeartrate: Double?
    let averageSpeed: Double?       // m/s
    let maxSpeed: Double?           // m/s
    let averageCadence: Double?
    let averageWatts: Double?
    let kilojoules: Double?

    // MARK: - Computed conversions
    var distanceMiles: Double { distance * 0.000621371 }
    var durationFormatted: String {
        let h = movingTime / 3600
        let m = (movingTime % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    enum CodingKeys: String, CodingKey {
        case id, name, type, distance
        case sportType        = "sport_type"
        case movingTime       = "moving_time"
        case elapsedTime      = "elapsed_time"
        case totalElevationGain = "total_elevation_gain"
        case startDate        = "start_date"
        case averageHeartrate = "average_heartrate"
        case maxHeartrate     = "max_heartrate"
        case averageSpeed     = "average_speed"
        case maxSpeed         = "max_speed"
        case averageCadence   = "average_cadence"
        case averageWatts     = "average_watts"
        case kilojoules
    }
}

/// Strava OAuth token response.
struct StravaTokenResponse: Decodable {
    let tokenType: String
    let expiresAt: Int
    let expiresIn: Int
    let refreshToken: String
    let accessToken: String
    let athlete: StravaAthlete?

    enum CodingKeys: String, CodingKey {
        case tokenType    = "token_type"
        case expiresAt    = "expires_at"
        case expiresIn    = "expires_in"
        case refreshToken = "refresh_token"
        case accessToken  = "access_token"
        case athlete
    }
}
