import SwiftUI
import ValorantAPI

struct SkinPicker: View {
	@Binding var gun: Loadout.Gun
	var inventory: Inventory
	
	var body: some View {
		AssetsUnwrappingView { assets in
			if let weapon = assets.weapons[gun.id] {
				let skins: [ResolvedLevel] = weapon.skins.map {
					let index = $0.levels.lastIndex { inventory.owns($0.id) } ?? 0
					return ResolvedLevel(weapon: weapon, skin: $0, level: $0.levels[index], levelIndex: index)
				}
				SearchableAssetPicker(
					allItems: .init(values: skins),
					ownedItems: .init(skins.lazy.map(\.id).filter(inventory.owns)),
					rowContent: skinPickerRow(for:)
				)
				.navigationTitle("Choose Skin")
			}
		}
	}
	
	@ViewBuilder
	func skinPickerRow(for skin: ResolvedLevel) -> some View {
		let isSelected = gun.skin.skin == skin.skin.id
		VStack {
			skin.displayIcon?.view()
				.frame(height: 60)
				.frame(maxWidth: .infinity)
			
			SelectableRow(isSelected: isSelected) {
				gun.skin = .init(
					skin: skin.skin.id,
					level: skin.level.id,
					chroma: skin.skin.chromas.first!.id
				)
			} content: {
				Text(skin.displayName)
					.frame(maxWidth: .infinity, alignment: .leading)
					.foregroundColor(.primary)
			}
		}
		.padding(.vertical, 8)
		.listRowBackground(ZStack {
			Color.secondaryGroupedBackground
			Color.accentColor.opacity(isSelected ? 0.1 : 0)
		})
	}
}

extension ResolvedLevel: SearchableAsset {
	var searchableText: String {
		level.displayName ?? skin.displayName
	}
}
