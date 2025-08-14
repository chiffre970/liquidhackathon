import SwiftUI
import CoreData

struct ActionItemsView: View {
    @ObservedObject var meeting: Meeting
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingAddItem = false
    @State private var filterOption = FilterOption.all
    @State private var sortOption = SortOption.priority
    
    enum FilterOption: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case completed = "Completed"
        case overdue = "Overdue"
    }
    
    enum SortOption: String, CaseIterable {
        case priority = "Priority"
        case deadline = "Deadline"
        case owner = "Owner"
    }
    
    var filteredItems: [ActionItem] {
        let items = meeting.actionItemsArray
        
        let filtered = items.filter { item in
            switch filterOption {
            case .all:
                return true
            case .pending:
                return !item.isCompleted
            case .completed:
                return item.isCompleted
            case .overdue:
                return !item.isCompleted && (item.deadline ?? Date.distantFuture) < Date()
            }
        }
        
        return filtered.sorted { item1, item2 in
            switch sortOption {
            case .priority:
                return priorityValue(item1.priority) > priorityValue(item2.priority)
            case .deadline:
                let date1 = item1.deadline ?? Date.distantFuture
                let date2 = item2.deadline ?? Date.distantFuture
                return date1 < date2
            case .owner:
                let owner1 = item1.owner ?? "zzz"
                let owner2 = item2.owner ?? "zzz"
                return owner1 < owner2
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            filterAndSortBar
            
            if filteredItems.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredItems, id: \.id) { item in
                            ActionItemCard(
                                item: item,
                                onUpdate: { updatedItem in
                                    updateActionItem(updatedItem)
                                },
                                onDelete: {
                                    deleteActionItem(item)
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Action Items")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddItem = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddActionItemView(meeting: meeting) { newItem in
                addActionItem(newItem)
            }
        }
    }
    
    private var filterAndSortBar: some View {
        VStack(spacing: 0) {
            Picker("Filter", selection: $filterOption) {
                ForEach(FilterOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.top)
            
            HStack {
                Text("Sort by:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Sort", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Spacer()
                
                Text("\(filteredItems.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No action items")
                .font(.headline)
            
            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if filterOption != .all {
                Button("Show All Items") {
                    filterOption = .all
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyStateMessage: String {
        switch filterOption {
        case .all:
            return "No action items were extracted from this meeting"
        case .pending:
            return "No pending action items"
        case .completed:
            return "No completed action items"
        case .overdue:
            return "No overdue action items"
        }
    }
    
    private func priorityValue(_ priority: ActionItem.Priority) -> Int {
        switch priority {
        case .urgent: return 4
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
    
    private func updateActionItem(_ item: ActionItem) {
        var items = meeting.actionItemsArray
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            meeting.actionItemsArray = items
            
            do {
                try viewContext.save()
            } catch {
                print("Failed to update action item: \(error)")
            }
        }
    }
    
    private func addActionItem(_ item: ActionItem) {
        var items = meeting.actionItemsArray
        items.append(item)
        meeting.actionItemsArray = items
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to add action item: \(error)")
        }
    }
    
    private func deleteActionItem(_ item: ActionItem) {
        var items = meeting.actionItemsArray
        items.removeAll { $0.id == item.id }
        meeting.actionItemsArray = items
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to delete action item: \(error)")
        }
    }
}

struct ActionItemCard: View {
    let item: ActionItem
    let onUpdate: (ActionItem) -> Void
    let onDelete: () -> Void
    
    @State private var isExpanded = false
    @State private var showingEditSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Button(action: toggleCompletion) {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(item.isCompleted ? .green : priorityColor)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.task)
                        .font(.body)
                        .strikethrough(item.isCompleted)
                        .foregroundColor(item.isCompleted ? .secondary : .primary)
                    
                    HStack(spacing: 12) {
                        if let owner = item.owner {
                            Label(owner, systemImage: "person.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let deadline = item.deadline {
                            Label(deadline.formatted(date: .abbreviated, time: .omitted), 
                                  systemImage: "calendar")
                                .font(.caption)
                                .foregroundColor(deadlineColor(deadline))
                        }
                        
                        Label(item.priority.rawValue.capitalized, 
                              systemImage: "flag.fill")
                            .font(.caption)
                            .foregroundColor(priorityColor)
                    }
                    
                    if isExpanded, let context = item.context {
                        Text(context)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                
                Spacer()
                
                Menu {
                    Button(action: { isExpanded.toggle() }) {
                        Label(isExpanded ? "Collapse" : "Expand", 
                              systemImage: isExpanded ? "chevron.up" : "chevron.down")
                    }
                    
                    Button(action: { showingEditSheet = true }) {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(backgroundGradient)
        .cornerRadius(12)
        .sheet(isPresented: $showingEditSheet) {
            EditActionItemView(item: item) { updatedItem in
                onUpdate(updatedItem)
            }
        }
    }
    
    private var priorityColor: Color {
        switch item.priority {
        case .urgent: return .red
        case .high: return .orange
        case .medium: return .blue
        case .low: return .gray
        }
    }
    
    private var backgroundGradient: LinearGradient {
        let baseColor = item.isCompleted ? Color.green : priorityColor
        return LinearGradient(
            colors: [baseColor.opacity(0.05), baseColor.opacity(0.02)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private func deadlineColor(_ deadline: Date) -> Color {
        if item.isCompleted {
            return .secondary
        }
        
        let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0
        
        if daysUntil < 0 {
            return .red
        } else if daysUntil <= 1 {
            return .orange
        } else if daysUntil <= 7 {
            return .yellow
        } else {
            return .secondary
        }
    }
    
    private func toggleCompletion() {
        var updatedItem = item
        updatedItem.isCompleted.toggle()
        onUpdate(updatedItem)
    }
}

struct AddActionItemView: View {
    let meeting: Meeting
    let onAdd: (ActionItem) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var task = ""
    @State private var owner = ""
    @State private var hasDeadline = false
    @State private var deadline = Date()
    @State private var priority = ActionItem.Priority.medium
    @State private var context = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Task Details") {
                    TextField("Task description", text: $task, axis: .vertical)
                        .lineLimit(3...6)
                    
                    TextField("Assigned to (optional)", text: $owner)
                    
                    Picker("Priority", selection: $priority) {
                        Text("Low").tag(ActionItem.Priority.low)
                        Text("Medium").tag(ActionItem.Priority.medium)
                        Text("High").tag(ActionItem.Priority.high)
                        Text("Urgent").tag(ActionItem.Priority.urgent)
                    }
                }
                
                Section("Deadline") {
                    Toggle("Set deadline", isOn: $hasDeadline)
                    
                    if hasDeadline {
                        DatePicker("Due date", selection: $deadline, displayedComponents: .date)
                    }
                }
                
                Section("Context") {
                    TextField("Additional context (optional)", text: $context, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("New Action Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let newItem = ActionItem(
                            task: task,
                            owner: owner.isEmpty ? nil : owner,
                            deadline: hasDeadline ? deadline : nil,
                            isCompleted: false,
                            priority: priority,
                            context: context.isEmpty ? nil : context
                        )
                        onAdd(newItem)
                        dismiss()
                    }
                    .disabled(task.isEmpty)
                }
            }
        }
    }
}

struct EditActionItemView: View {
    let item: ActionItem
    let onUpdate: (ActionItem) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var task: String
    @State private var owner: String
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @State private var priority: ActionItem.Priority
    @State private var context: String
    @State private var isCompleted: Bool
    
    init(item: ActionItem, onUpdate: @escaping (ActionItem) -> Void) {
        self.item = item
        self.onUpdate = onUpdate
        self._task = State(initialValue: item.task)
        self._owner = State(initialValue: item.owner ?? "")
        self._hasDeadline = State(initialValue: item.deadline != nil)
        self._deadline = State(initialValue: item.deadline ?? Date())
        self._priority = State(initialValue: item.priority)
        self._context = State(initialValue: item.context ?? "")
        self._isCompleted = State(initialValue: item.isCompleted)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Task Details") {
                    TextField("Task description", text: $task, axis: .vertical)
                        .lineLimit(3...6)
                    
                    TextField("Assigned to", text: $owner)
                    
                    Picker("Priority", selection: $priority) {
                        Text("Low").tag(ActionItem.Priority.low)
                        Text("Medium").tag(ActionItem.Priority.medium)
                        Text("High").tag(ActionItem.Priority.high)
                        Text("Urgent").tag(ActionItem.Priority.urgent)
                    }
                    
                    Toggle("Completed", isOn: $isCompleted)
                }
                
                Section("Deadline") {
                    Toggle("Has deadline", isOn: $hasDeadline)
                    
                    if hasDeadline {
                        DatePicker("Due date", selection: $deadline, displayedComponents: .date)
                    }
                }
                
                Section("Context") {
                    TextField("Additional context", text: $context, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Edit Action Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let updatedItem = ActionItem(
                            id: item.id,
                            task: task,
                            owner: owner.isEmpty ? nil : owner,
                            deadline: hasDeadline ? deadline : nil,
                            isCompleted: isCompleted,
                            priority: priority,
                            context: context.isEmpty ? nil : context
                        )
                        onUpdate(updatedItem)
                        dismiss()
                    }
                    .disabled(task.isEmpty)
                }
            }
        }
    }
}