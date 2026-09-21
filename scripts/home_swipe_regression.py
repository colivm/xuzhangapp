#!/usr/bin/env python3
"""Home swipe/delete source contracts; not SwiftUI gesture or device performance tests."""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
home = (ROOT / "NativeDemoApp/Views/HomeView.swift").read_text(encoding="utf-8")
trace = (ROOT / "NativeDemoApp/Views/StatsWebView.swift").read_text(encoding="utf-8")
editor = (ROOT / "NativeDemoApp/Views/FocusedRecordEditor.swift").read_text(encoding="utf-8")


def section(source, start, end):
    assert source.count(start) == 1, start
    return source.split(start, 1)[1].split(end, 1)[0]


swipe = section(home, "private struct HomeTodaySwipeRow<", "private enum PetBubbleSource:")
trace_swipe = section(trace, "private struct TraceSwipeRow<", "struct StatsWebView:")
# The gesture contract is copied locally; the accepted trace implementation remains independent.
assert swipe.replace("home-today-swipe-", "trace-swipe-") == trace_swipe
for required in (
    "@Binding var openItemID: UUID?", "@GestureState private var dragTranslation: CGFloat = 0",
    "isEnabled && openItemID == itemID", '"home-today-swipe-\\(itemID.uuidString)"',
    ".coordinateSpace(name: coordinateSpaceName)", "coordinateSpace: .named(coordinateSpaceName)",
    ".simultaneousGesture(swipeGesture)", "transaction.disablesAnimations = true",
    ".contentShape(Rectangle())", ".onTapGesture(perform: onTap)",
    "openItemID = itemID", "openItemID = nil",
):
    assert required in swipe, required
for obsolete in ("TodaySwipeDragState", "todaySwipeDragState", "todayDeletingItemID",
                 "todayRowSwipeGesture", "todaySwipeHandle"):
    assert obsolete not in home, obsolete
home_view = section(home, "struct HomeView: View", "struct TodayPlaybackPresentationPayload:")
assert "@GestureState" not in home_view
assert re.findall(r"\.scrollDisabled\(([^\n]+)\)", home_view) == ["todayInlineEditingItemID != nil"]

sheet = section(home, "private var todayRecordsSheet:", "private var todayRecordsMetaText:")
assert "LazyVStack(alignment: .leading, spacing: 8)" in sheet
assert "ForEach(Array(homeViewModel.todayItems.enumerated()), id: \\.element.id)" in sheet
assert ".allowsHitTesting(todayInlineEditingItemID == nil)" in sheet
assert "abs(value.translation.height) > abs(value.translation.width)" in sheet
assert 'isPresented: $showTodayDeleteConfirmation' in sheet
confirmed = section(sheet, 'Button("删除", role: .destructive)', 'Button("取消", role: .cancel)')
assert "if let todayPendingDeleteItem" in confirmed
assert "deleteTodayRecord(todayPendingDeleteItem)" in confirmed
assert "todayPendingDeleteItem = nil" in confirmed
cancelled = section(sheet, 'Button("取消", role: .cancel)', "} message:")
assert "todayPendingDeleteItem = nil" in cancelled and "deleteTodayRecord" not in cancelled

row = section(home, "private func todayRecordInlineRow(", "private func todayRecordSummary(")
for required in (
    "HomeTodaySwipeRow(", "itemID: item.id", "openItemID: $todaySwipedItemID",
    "let canSwipe = todayInlineEditingItemID == nil", "isEnabled: canSwipe",
    "animation: todayEditSpring", "if todaySwipedItemID == item.id",
    "else if todaySwipedItemID != nil", "if item.hasMemoryImages", "openRecord(item)",
    "todayInlineEditingItemID = item.id", ".id(item.id)", ".transition(.identity)",
    "todayRecordRowBackground(item: item, isEditing: isEditing)",
    "todayRecordRowBorder(item: item, isEditing: isEditing)",
):
    assert required in row, required
assert row.index("else if todaySwipedItemID != nil") < row.index("if item.hasMemoryImages")
assert "isDeleting" not in row and ".frame(height:" not in row
routes = section(home, "private func openRecord(", "private func requestAttachMemoryImage(")
assert "todayRecordsDismissRoute = .memoryDetail(latestItem(matching: item))" in routes
assert "memoryDetailItem = latestItem(matching: item)" in routes
assert "editingItem = latestItem(matching: item)" in routes

actions = section(home, "private func todaySwipeActions(", "private func requestTodayDeleteConfirmation(")
assert "requestTodayDeleteConfirmation(for: item)" in actions
assert "deleteTodayRecord" not in actions
assert '.accessibilityLabel("删除这条账单")' in actions
assert ".accessibilityHidden(!isVisible)" in actions and ".allowsHitTesting(isVisible)" in actions
request = section(home, "private func requestTodayDeleteConfirmation(", "private func deleteTodayRecord(")
assert "todayPendingDeleteItem = item" in request and "showTodayDeleteConfirmation = true" in request
assert "deleteItem" not in request
focused = section(home, "private var todayFocusedRecordOverlay:", "private var todayRecordsGradientBackground:")
assert "onDelete: {\n                        deleteTodayRecord(item)" in focused
assert ".confirmationDialog(" in editor and 'Button("删除", role: .destructive) {\n                onDelete()' in editor

delete = section(home, "private func deleteTodayRecord(", "private func handleSheetDismissRoute(")
assert "guard homeViewModel.deleteItem(id: item.id) else { return }" in delete
assert delete.index("guard homeViewModel.deleteItem") < delete.index("todayInlineEditingItemID = nil")
assert delete.index("guard homeViewModel.deleteItem") < delete.index("todaySwipedItemID = nil")
for forbidden in ("asyncAfter", "Task", "sleep", "withAnimation", "IndexSet", "firstIndex", "delete(at:"):
    assert forbidden not in delete, forbidden
spring = section(home, "private var todayEditSpring:", "private func todaySwipeActions(")
assert "Animation?" in spring and "reduceMotion ? nil : .spring(" in spring

print("home_swipe_regression: OK (trace-aligned local gesture, stable-ID immediate deletion, confirmation, routes and Reduce Motion; source checks only)")
