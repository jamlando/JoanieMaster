import Foundation

// MARK: - COPPA Compliance Model

struct COPPACompliance: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let childId: UUID
    let parentalConsentGiven: Bool
    let consentDate: Date
    let consentMethod: ConsentMethod
    let dataRetentionPeriod: Int // days
    let aiAnalysisOptIn: Bool
    let dataSharingOptIn: Bool
    let marketingOptIn: Bool
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case childId = "child_id"
        case parentalConsentGiven = "parental_consent_given"
        case consentDate = "consent_date"
        case consentMethod = "consent_method"
        case dataRetentionPeriod = "data_retention_period"
        case aiAnalysisOptIn = "ai_analysis_opt_in"
        case dataSharingOptIn = "data_sharing_opt_in"
        case marketingOptIn = "marketing_opt_in"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // MARK: - Initializers
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        childId: UUID,
        parentalConsentGiven: Bool = false,
        consentDate: Date? = nil,
        consentMethod: ConsentMethod = .none,
        dataRetentionPeriod: Int = 365, // Default 1 year
        aiAnalysisOptIn: Bool = false,
        dataSharingOptIn: Bool = false,
        marketingOptIn: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.childId = childId
        self.parentalConsentGiven = parentalConsentGiven
        self.consentDate = consentDate ?? Date()
        self.consentMethod = consentMethod
        self.dataRetentionPeriod = dataRetentionPeriod
        self.aiAnalysisOptIn = aiAnalysisOptIn
        self.dataSharingOptIn = dataSharingOptIn
        self.marketingOptIn = marketingOptIn
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Computed Properties
    
    var isConsentValid: Bool {
        return parentalConsentGiven && consentMethod != .none
    }
    
    var dataExpirationDate: Date? {
        guard isConsentValid else { return nil }
        return Calendar.current.date(byAdding: .day, value: dataRetentionPeriod, to: consentDate)
    }
    
    var isDataExpired: Bool {
        guard let expirationDate = dataExpirationDate else { return false }
        return Date() > expirationDate
    }
    
    // MARK: - Helper Methods
    
    func withUpdatedConsent(
        given: Bool,
        method: ConsentMethod,
        aiOptIn: Bool = false,
        dataSharingOptIn: Bool = false,
        marketingOptIn: Bool = false
    ) -> COPPACompliance {
        return COPPACompliance(
            id: id,
            userId: userId,
            childId: childId,
            parentalConsentGiven: given,
            consentDate: given ? Date() : consentDate,
            consentMethod: method,
            dataRetentionPeriod: dataRetentionPeriod,
            aiAnalysisOptIn: aiOptIn,
            dataSharingOptIn: dataSharingOptIn,
            marketingOptIn: marketingOptIn,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
}

// MARK: - Consent Method

enum ConsentMethod: String, Codable, CaseIterable {
    case none = "none"
    case email = "email"
    case phone = "phone"
    case postal = "postal"
    case digitalSignature = "digital_signature"
    case videoCall = "video_call"
    
    var displayName: String {
        switch self {
        case .none:
            return "No Consent Given"
        case .email:
            return "Email Confirmation"
        case .phone:
            return "Phone Verification"
        case .postal:
            return "Postal Mail"
        case .digitalSignature:
            return "Digital Signature"
        case .videoCall:
            return "Video Call Verification"
        }
    }
    
    var isVerifiable: Bool {
        return self != .none
    }
}

// MARK: - COPPA Compliance Service

@MainActor
class COPPAComplianceService: ObservableObject {
    @Published var complianceRecords: [COPPACompliance] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Public Methods
    
    func createComplianceRecord(for childId: UUID, userId: UUID) -> COPPACompliance {
        return COPPACompliance(
            userId: userId,
            childId: childId,
            parentalConsentGiven: false,
            consentMethod: .none
        )
    }
    
    func updateConsent(
        for complianceId: UUID,
        given: Bool,
        method: ConsentMethod,
        aiOptIn: Bool = false,
        dataSharingOptIn: Bool = false,
        marketingOptIn: Bool = false
    ) {
        if let index = complianceRecords.firstIndex(where: { $0.id == complianceId }) {
            complianceRecords[index] = complianceRecords[index].withUpdatedConsent(
                given: given,
                method: method,
                aiOptIn: aiOptIn,
                dataSharingOptIn: dataSharingOptIn,
                marketingOptIn: marketingOptIn
            )
        }
    }
    
    func getComplianceRecord(for childId: UUID) -> COPPACompliance? {
        return complianceRecords.first { $0.childId == childId }
    }
    
    func isConsentRequired(for childId: UUID) -> Bool {
        guard let record = getComplianceRecord(for: childId) else { return true }
        return !record.isConsentValid
    }
    
    func canPerformAIAnalysis(for childId: UUID) -> Bool {
        guard let record = getComplianceRecord(for: childId) else { return false }
        return record.isConsentValid && record.aiAnalysisOptIn
    }
    
    func canShareData(for childId: UUID) -> Bool {
        guard let record = getComplianceRecord(for: childId) else { return false }
        return record.isConsentValid && record.dataSharingOptIn
    }
    
    func canSendMarketing(for childId: UUID) -> Bool {
        guard let record = getComplianceRecord(for: childId) else { return false }
        return record.isConsentValid && record.marketingOptIn
    }
    
    func getExpiredRecords() -> [COPPACompliance] {
        return complianceRecords.filter { $0.isDataExpired }
    }
    
    func cleanupExpiredData() {
        let expiredRecords = getExpiredRecords()
        for record in expiredRecords {
            // TODO: Implement data deletion for expired records
            logInfo("COPPA: Data expired for child \(record.childId), should be deleted")
        }
    }
}

// MARK: - COPPA Compliance View Model

@MainActor
class COPPAComplianceViewModel: ObservableObject {
    @Published var currentCompliance: COPPACompliance?
    @Published var showConsentForm: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let complianceService: COPPAComplianceService
    
    init(complianceService: COPPAComplianceService) {
        self.complianceService = complianceService
    }
    
    func loadCompliance(for childId: UUID) {
        currentCompliance = complianceService.getComplianceRecord(for: childId)
    }
    
    func showConsentFormIfNeeded(for childId: UUID) {
        if complianceService.isConsentRequired(for: childId) {
            showConsentForm = true
        }
    }
    
    func submitConsent(
        given: Bool,
        method: ConsentMethod,
        aiOptIn: Bool = false,
        dataSharingOptIn: Bool = false,
        marketingOptIn: Bool = false
    ) {
        guard let compliance = currentCompliance else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Update compliance record
        complianceService.updateConsent(
            for: compliance.id,
            given: given,
            method: method,
            aiOptIn: aiOptIn,
            dataSharingOptIn: dataSharingOptIn,
            marketingOptIn: marketingOptIn
        )
        
        // Reload current compliance
        loadCompliance(for: compliance.childId)
        
        isLoading = false
        showConsentForm = false
    }
}
