import SwiftUI
import Charts
import ValorantAPI

private typealias Playtime = Statistics.Playtime

@available(iOS 16.0, *)
struct PlaytimeView: View {
	var statistics: Statistics
	
	private var playtime: Playtime { statistics.playtime }
	
	var body: some View {
		List {
			Section("Over Time") {
				chartOverTime()
			}
			
			Section("Overall") {
				Row(entry: playtime.total) {
					Text("Total Playtime")
				}
			}
			
			Section("By Queue") {
				ForEach(playtime.byQueue.sorted(), id: \.key) { queue, time in
					Row(entry: time) {
						HStack(spacing: 12) {
							GameModeImage(id: statistics.modeByQueue[queue]!)
								.frame(height: 32)
								.foregroundColor(.valorantRed)
							QueueLabel(queue: queue ?? .custom)
						}
					}
				}
			}
			
			Section("By Map") {
				ForEach(playtime.byMap.sorted(), id: \.key) { map, time in
					Row(entry: time) {
						// tried adding icons but couldn't get them to look good
						MapImage.LabelText(mapID: map)
					}
				}
			}
			
			ExpandableList(
				title: "By Premade Teammate",
				entries: playtime.byPremade.sorted(), maxCount: 5,
				emptyPlaceholder: "No games played with premade teammates."
			) { teammate, playtime in
				TransparentNavigationLink {
					FilteredMatchListView(userID: statistics.userID, otherID: teammate, matches: playtime.games)
				} label: {
					Row(entry: playtime) {
						UserLabel(userID: teammate)
					}
				}
			}
			
			ExpandableList(
				title: "By Non-Premade Player",
				entries: playtime.byNonPremade.sorted(), maxCount: 3,
				emptyPlaceholder: "No non-premade players encountered repeatedly. (Un)lucky you!"
			) { player, playtime in
				TransparentNavigationLink {
					FilteredMatchListView(userID: statistics.userID, otherID: player, matches: playtime.games)
				} label: {
					Row(entry: playtime) {
						UserLabel(userID: player)
					}
				}
			}
		}
		.navigationTitle("Playtime")
	}
	
	@State var timeGrouping = DateBinSize.day
	
	@ViewBuilder
	func chartOverTime() -> some View {
		ChartOverTime(statistics: statistics, timeGrouping: timeGrouping)
			.aligningListRowSeparator()
			.padding(.vertical)
		
		Picker("Group by", selection: $timeGrouping) {
			ForEach(DateBinSize.allCases) { size in
				Text(size.name).tag(size)
			}
		}
	}
	
	private struct ExpandableList<Key: Hashable, RowContent: View>: View {
		var title: LocalizedStringKey
		var entries: [(key: Key, value: Playtime.Entry)]
		var maxCount: Int
		var emptyPlaceholder: LocalizedStringKey
		@ViewBuilder var row: (Key, Playtime.Entry) -> RowContent
		
		var body: some View {
			Section(title) {
				if entries.isEmpty {
					Text(emptyPlaceholder)
						.foregroundStyle(.secondary)
				} else {
					ForEach(entries.prefix(maxCount), id: \.key, content: row)
					if entries.count > maxCount {
						TransparentNavigationLink {
							List(entries, id: \.key, rowContent: row)
								.navigationTitle(title)
						} label: {
							let missingPlaytime: Playtime.Entry = entries
								.dropFirst(maxCount)
								.lazy
								.map(\.value)
								.reduce(.init(), +)
							Row(entry: missingPlaytime) {
								Text("\(entries.count - maxCount) more")
									.foregroundStyle(.secondary)
							}
						}
					}
				}
			}
		}
	}
	
	private struct Row<Label: View>: View {
		var entry: Playtime.Entry
		@ViewBuilder var label: Label
		
		var body: some View {
			HStack {
				label.fontWeight(.medium)
				
				Spacer()
				
				VStack(alignment: .trailing, spacing: 4) {
					Stats.DurationLabel(duration: entry.time)
						.fontWeight(.medium)
					// I tried to use automatic inflection here but it caused hangs of like 600ms when entering the view
					//Text("^[\(entry.games.count) matches](inflect: true, morphology: { partOfSpeech: \"noun\" })")
					Text(entry.games.count == 1 ? "1 match" : "\(entry.games.count) matches")
						.foregroundStyle(.secondary)
				}
				.fixedSize()
			}
		}
	}
	
	struct ChartOverTime: View {
		var statistics: Statistics
		var timeGrouping: DateBinSize
		
		var body: some View {
			Chart(statistics.matches) { match in
				BarMark(
					x: .value("Day", match.matchInfo.gameStart, unit: timeGrouping.component),
					y: .value("Playtime", match.matchInfo.gameLength / 3600)
				)
				.foregroundStyle(Color.valorantRed)
			}
			.chartYAxis {
				// .stride(by: .hour) just left me with empty content for some reason, so now i'm just quantizing to hours first
				AxisMarks { value in
					AxisValueLabel {
						let duration = Duration.seconds(3600 * value.as(TimeInterval.self)!)
						Text(duration, format: .units(allowed: [.hours, .minutes], width: .narrow))
					}
					AxisTick()
					AxisGridLine()
				}
			}
		}
	}
}

@available(iOS 16.0, *)
struct FilteredMatchListView: View {
	var userID: User.ID
	var otherID: User.ID
	var matches: [CompetitiveUpdate]
	let filter = MatchListFilter()
	
	var body: some View {
		List {
			Section {
				ViewThatFits {
					HStack {
						UserLabel(userID: otherID)
						Capsule()
							.opacity(0.2)
							.frame(height: 1)
							.frame(minWidth: 20)
							.layoutPriority(-1)
						UserLabel(userID: userID)
					}
					
					VStack(spacing: 4) {
						UserLabel(userID: otherID)
							.frame(maxWidth: .infinity, alignment: .leading)
						UserLabel(userID: userID)
							.frame(maxWidth: .infinity, alignment: .trailing)
					}
				}
				
				TransparentNavigationLink {
					MatchListView(userID: otherID)
				} label: {
					Label("View Full Profile", systemImage: "person")
				}
			}
			
			Section {
				ForEach(matches) { match in
					MatchCell(match: match, userID: userID, filter: filter)
				}
			}
		}
		.navigationTitle("Shared Matches")
	}
}

private extension Dictionary where Value == Playtime.Entry {
	func sorted() -> [(key: Key, value: Value)] {
		sorted { -$0.value.time } // descending
	}
}

@available(iOS 16.0, *)
extension PlaytimeView {
	init(statistics: Statistics) {
		self.init(
			statistics: statistics,
			timeGrouping: .smallestThatFits(statistics.matches.lazy.map(\.matchInfo.gameStart))
		)
	}
	
	static func overview(statistics: Statistics) -> ChartOverTime? {
		.init(
			statistics: statistics,
			timeGrouping: .smallestThatFits(statistics.matches.lazy.map(\.matchInfo.gameStart))
		)
	}
}

#if DEBUG
@available(iOS 16.0, *)
struct PlaytimeView_Previews: PreviewProvider {
    static var previews: some View {
		PlaytimeView(statistics: PreviewData.statistics)
			.withToolbar()
		
		FilteredMatchListView(
			userID: PreviewData.pregameInfo.team.players[1].id,
			otherID: PreviewData.pregameInfo.team.players[0].id,
			matches: PreviewData.matchList.matches
		)
		.withToolbar()
		.previewDisplayName("Filtered Match List")
		.environmentObject(BookmarkList())
    }
}
#endif
