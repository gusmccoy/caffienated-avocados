// Views/Profile/ProfileView.swift
// Athlete profile: name, "An Avocado since" date, and personal records.

import SwiftUI
import SwiftData

struct ProfileView: View {
    @State private var vm = ProfileViewModel()
    @Query private var allPRs: [PersonalRecord]
    @Query(sort: \PRMilestone.orderIndex) private var milestones: [PRMilestone]
    @Query private var allSessions: [WorkoutSession]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    profileHeaderCard
                    prSectionCard
                }
                .padding()
            }
            #if os(macOS)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .center)
            #endif
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        vm.openEditProfile()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }
            }
        }
        // Edit profile sheet
        .sheet(isPresented: $vm.isShowingEditProfile) {
            EditProfileSheet(vm: vm)
        }
        // Add PR sheet
        .sheet(isPresented: $vm.isShowingAddPR) {
            AddPRSheet(vm: vm, milestones: milestones, modelContext: modelContext)
        }
        // Add / edit milestone sheet
        .sheet(isPresented: $vm.isShowingAddMilestone) {
            AddMilestoneSheet(vm: vm, existingCount: milestones.count, modelContext: modelContext)
        }
    }

    // MARK: - Profile Header

    private var profileHeaderCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: "person.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                if vm.firstName.isEmpty {
                    Text("Your Profile")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Text(vm.firstName)
                        .font(.title3.weight(.bold))
                }
                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text(vm.avocadoMembershipLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .cardStyle()
    }

    // MARK: - PR Section

    private var prSectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Personal Records")
                    .font(.headline)
                Spacer()
                Button {
                    vm.openAddPR()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.orange)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            Picker("Mode", selection: $vm.prMode) {
                ForEach(ProfileViewModel.PRMode.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.segmented)

            if vm.prMode == .allTime {
                allTimePRList
            } else if vm.prMode == .ytd {
                ytdPRSection
            } else {
                milestonesSection
            }
        }
        .cardStyle()
    }

    // MARK: - All-Time PRs

    private var allTimePRList: some View {
        VStack(spacing: 0) {
            let bestPRs = vm.prs(for: nil, from: allPRs)
            if bestPRs.isEmpty {
                emptyState(message: "No personal records yet.\nTap + to add your first PR.")
            } else {
                ForEach(bestPRs) { pr in
                    PRRow(pr: pr) {
                        vm.deletePR(pr, modelContext: modelContext)
                    }
                    if pr.id != bestPRs.last?.id {
                        Divider().padding(.leading, 36)
                    }
                }
            }
        }
    }

    // MARK: - Year-to-Date (Strava derived)

    private var ytdPRSection: some View {
        let year = Calendar.current.component(.year, from: .now)
        let ytdPRs = allPRs.filter { $0.isDerivedFromStrava && $0.ytdYear == year }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Best Efforts \(year)")
                        .font(.subheadline.weight(.semibold))
                    Text("Derived from Strava splits")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    vm.deriveYTDPRs(from: allSessions, modelContext: modelContext)
                } label: {
                    if vm.isDerivedPRsLoading {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Label("Update", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .disabled(vm.isDerivedPRsLoading)
            }

            if ytdPRs.isEmpty {
                emptyState(message: "No YTD data yet.\nSync Strava activities with split data, then tap Update.")
            } else {
                let sorted = PRDistance.allCases.compactMap { dist in
                    ytdPRs.filter { $0.distance == dist }.min(by: { $0.timeSeconds < $1.timeSeconds })
                }
                VStack(spacing: 0) {
                    ForEach(sorted) { pr in
                        PRRow(pr: pr) {
                            vm.deletePR(pr, modelContext: modelContext)
                        }
                        if pr.id != sorted.last?.id {
                            Divider().padding(.leading, 36)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Milestones

    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if milestones.isEmpty {
                emptyState(message: "No milestones yet.\nCreate eras like \"Post College\" or \"After Injury\" to track PRs by period.")
            } else {
                ForEach(milestones) { milestone in
                    MilestoneCard(
                        milestone: milestone,
                        allPRs: allPRs,
                        vm: vm,
                        modelContext: modelContext
                    )
                }
            }
            Button {
                vm.openAddMilestone()
            } label: {
                Label("Add Milestone Era", systemImage: "plus")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Empty State

    private func emptyState(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "trophy")
                .font(.largeTitle)
                .foregroundStyle(.orange.opacity(0.4))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - PR Row

private struct PRRow: View {
    let pr: PersonalRecord
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: pr.distance.systemImage)
                .foregroundStyle(.orange)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(pr.distance.rawValue)
                    .font(.subheadline.weight(.medium))
                Text(pr.dateAchieved.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(pr.formattedTime)
                .font(.subheadline.monospacedDigit().weight(.semibold))
        }
        .padding(.vertical, 8)
        .contextMenu {
            Button("Delete PR", role: .destructive) { onDelete() }
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) { onDelete() }
        }
    }
}

// MARK: - Milestone Card

private struct MilestoneCard: View {
    let milestone: PRMilestone
    let allPRs: [PersonalRecord]
    let vm: ProfileViewModel
    let modelContext: ModelContext

    private var bestPRs: [PersonalRecord] {
        vm.prs(for: milestone.id, from: allPRs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(milestone.name)
                        .font(.subheadline.weight(.semibold))
                    Text("Since \(milestone.startDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button("Add PR") {
                        vm.openAddPR(milestoneId: milestone.id)
                    }
                    Button("Edit Era") {
                        vm.openEditMilestone(milestone)
                    }
                    Divider()
                    Button("Delete Era", role: .destructive) {
                        vm.deleteMilestone(milestone, allPRs: allPRs, modelContext: modelContext)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if bestPRs.isEmpty {
                Text("No PRs yet — tap ••• to add one.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(bestPRs) { pr in
                        PRRow(pr: pr) {
                            vm.deletePR(pr, modelContext: modelContext)
                        }
                        if pr.id != bestPRs.last?.id {
                            Divider().padding(.leading, 36)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Edit Profile Sheet

private struct EditProfileSheet: View {
    @Bindable var vm: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("First name", text: $vm.editFirstName)
                        .autocorrectionDisabled()
                }
            }
            #if os(macOS)
            .formStyle(.grouped)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .center)
            #endif
            .navigationTitle("Edit Profile")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { vm.saveProfile() }
                }
            }
        }
    }
}

// MARK: - Add PR Sheet

private struct AddPRSheet: View {
    @Bindable var vm: ProfileViewModel
    let milestones: [PRMilestone]
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Distance") {
                    Picker("Distance", selection: $vm.prFormDistance) {
                        ForEach(PRDistance.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                }

                Section("Time") {
                    HStack {
                        Picker("Hours", selection: $vm.prFormHours) {
                            ForEach(0...5, id: \.self) { Text("\($0)h").tag($0) }
                        }
                        #if os(macOS)
                        .pickerStyle(.menu)
                        #else
                        .pickerStyle(.wheel)
                        .frame(width: 70)
                        .clipped()
                        #endif

                        Picker("Min", selection: $vm.prFormMinutes) {
                            ForEach(0...59, id: \.self) { Text(String(format: "%02d", $0) + "m").tag($0) }
                        }
                        #if os(macOS)
                        .pickerStyle(.menu)
                        #else
                        .pickerStyle(.wheel)
                        .frame(width: 80)
                        .clipped()
                        #endif

                        Picker("Sec", selection: $vm.prFormSeconds) {
                            ForEach(0...59, id: \.self) { Text(String(format: "%02d", $0) + "s").tag($0) }
                        }
                        #if os(macOS)
                        .pickerStyle(.menu)
                        #else
                        .pickerStyle(.wheel)
                        .frame(width: 80)
                        .clipped()
                        #endif
                    }
                    #if !os(macOS)
                    .frame(height: 100)
                    #endif

                    if vm.prFormTimeSeconds > 0 {
                        HStack {
                            Text("Time")
                            Spacer()
                            Text(vm.prFormTimeSeconds.formattedAsTime)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Date") {
                    DatePicker("Date Achieved", selection: $vm.prFormDate, displayedComponents: .date)
                }

                if !milestones.isEmpty {
                    Section("Era (optional)") {
                        Picker("Milestone", selection: $vm.prFormMilestoneId) {
                            Text("All-Time").tag(UUID?.none)
                            ForEach(milestones) { m in
                                Text(m.name).tag(Optional(m.id))
                            }
                        }
                    }
                }

                Section("Notes") {
                    TextField("Optional", text: $vm.prFormNotes)
                }
            }
            #if os(macOS)
            .formStyle(.grouped)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .center)
            #endif
            .navigationTitle("Add Personal Record")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { vm.savePR(modelContext: modelContext) }
                        .disabled(!vm.isPRFormValid)
                }
            }
        }
    }
}

// MARK: - Add Milestone Sheet

private struct AddMilestoneSheet: View {
    @Bindable var vm: ProfileViewModel
    let existingCount: Int
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    var isEditing: Bool { vm.editingMilestone != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Post College", text: $vm.milestoneFormName)
                        .autocorrectionDisabled()
                } header: {
                    Text("Era Name")
                }

                Section {
                    DatePicker("Start Date", selection: $vm.milestoneFormStartDate, displayedComponents: .date)
                } header: {
                    Text("When Did This Era Begin?")
                } footer: {
                    Text("PRs logged on or after this date can be assigned to this era.")
                }
            }
            #if os(macOS)
            .formStyle(.grouped)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, alignment: .center)
            #endif
            .navigationTitle(isEditing ? "Edit Era" : "Add Milestone Era")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vm.saveMilestone(modelContext: modelContext, existingCount: existingCount)
                    }
                    .disabled(vm.milestoneFormName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [PersonalRecord.self, PRMilestone.self], inMemory: true)
}
