import SwiftUI

struct InAppStorefront: View {
	@ObservedObject var store: InAppStore
	@State var purchaseError: Error?
	
	var body: some View {
		HStack {
			VStack(alignment: .leading, spacing: 12) {
				Text("Recon Bolt Pro")
					.font(.title2.bold())
					.foregroundColor(.blue)
				
				VStack(alignment: .leading, spacing: 8) {
					if store.ownsProVersion {
						Text("Thank you for supporting Recon Bolt!", comment: "Pro Store").font(.callout)
						Text("I hope you enjoy the pro features :)", comment: "Pro Store").font(.callout)
					} else {
						let bullets = [
							Text("Support Further Development!", comment: "Pro Store"),
							Text("Multiple Accounts", comment: "Pro Store"),
							Text("Home Screen Widgets", comment: "Pro Store"),
							Text("Advanced Stats", comment: "Pro Store"),
						]
						ForEach(bullets.indexed(), id: \.index) { _, bullet in
							HStack(spacing: 8) {
								Circle().frame(width: 3, height: 3)
								bullet
							}
						}
						.font(.footnote)
					}
				}
			}
			.padding(.vertical, 8)
			
			Spacer()
			
			Image("Pro Icon")
				.resizable()
				.aspectRatio(contentMode: .fit)
				.frame(minWidth: 120, maxHeight: 256)
				.layoutPriority(-1)
		}
		
		NavigationLink {
			ProFeaturesOverview()
		} label: {
			Text("View All Features", comment: "Pro Store")
		}
		
		if !store.ownsProVersion {
			purchaseButton
		}
	}
	
	@ViewBuilder
	var purchaseButton: some View {
		if let product = store.proVersion.resolved {
			AsyncButton {
				do {
					try await store.purchase(product)
				} catch {
					print(error)
					purchaseError = error
				}
			} label: {
				Text("Purchase – \(product.displayPrice)", comment: "Pro Store (placeholder filled with formatted currency)")
					.frame(maxWidth: .infinity)
			}
			.alert("Purchase Failed!", for: $purchaseError)
		} else {
			HStack {
				Text("Loading Store Info…", comment: "Pro Store")
					.foregroundStyle(.secondary)
				Spacer()
				ProgressView()
			}
			.task { await store.fetchProducts() }
		}
	}
}

struct ProFeaturesOverview: View {
	var body: some View {
		List {
			Section {
				description(Text("Support Development :)", comment: "Pro Features List")) {
					Text("Recon Bolt does not have and will never have ads. The only way it can make money is through in-app purchases.", comment: "Pro Features List")
					
					Text("Getting money from Recon Bolt gives me the flexibility and motivation to keep improving the app!", comment: "Pro Features List")
				}
			}
			
			Section {
				image("multiple accounts")
				
				description(Text("Multiple Account Support", comment: "Pro Features List")) {
					Text("Add multiple accounts and seamlessly switch between them at any time.", comment: "Pro Features List")
					Text("If you have accounts in multiple regions to play with friends around the world, this is the feature for you!", comment: "Pro Features List")
				}
			}
			
			Section {
				image("widgets")
				
				description(Text("Home Screen Widgets", comment: "Pro Features List")) {
					Text("View your storefront, daily/weekly missions, or current rank without even having to open the app!", comment: "Pro Features List")
					Text("If you have multiple accounts, you can configure separate widgets for each and have them on your Home Screen at the same time.", comment: "Pro Features List")
					Text("Note: Widgets are only available on iOS 16 and newer.", comment: "Pro Features List")
						.fontWeight(.medium)
						.font(.footnote)
				}
			}
			
			Section {
				image("stats")
				description(Text("Advanced Stats", comment: "Pro Features List")) {
					Text("Gather statistics from anyone's games to gain insights on things like time played by mode/premade, headshot rate over time/by weapon, win rate over time/by map & side, and more!", comment: "Pro Features List")
					Text("Note: Statistics are only available on iOS 16 and newer.", comment: "Pro Features List")
						.fontWeight(.medium)
						.font(.footnote)
				}
			}
			
			Section {
				HStack {
					Spacer()
					AppIcon.Thumbnail(icon: .default, size: 120)
					Spacer()
					AppIcon.Thumbnail(icon: .proBlue, size: 120)
					Spacer()
				}
				.padding()
				.frame(maxHeight: 256)
				
				description(Text("Exclusive App Icon", comment: "Pro Features List")) {
					Text("As thanks for your support, you get to show off your status with an exclusive app icon!", comment: "Pro Features List")
					Text("(You can switch between available icons at any time.)", comment: "Pro Features List")
				}
			}
			
			Section {
				description(Text("Family Sharing", comment: "Pro Features List")) {
					Text("Recon Bolt Pro supports Family Sharing, meaning if just one member of your iCloud family buys it, everyone can use it!", comment: "Pro Features List")
				}
			}
		}
		.navigationTitle("Pro Features")
	}
	
	func image(_ name: String) -> some View {
		Image("pro features/\(name)")
			.resizable()
			.aspectRatio(contentMode: .fit)
			.fixedSize(horizontal: false, vertical: true)
			.frame(maxWidth: 414)
			.frame(maxWidth: .infinity)
			.listRowInsets(.init())
			.aligningListRowSeparator()
			.overlay {
				GeometryReader { geometry in
					// unfortunately ContainerRelativeShape doesn't recognize list cells
					let path = UIBezierPath(
						roundedRect: .init(origin: .zero, size: geometry.size),
						byRoundingCorners: [.topLeft, .topRight],
						cornerRadii: .init(width: 10, height: 10)
					)
					Path(path.cgPath)
						.stroke(lineWidth: 2)
						.opacity(0.1)
						.blendMode(.hardLight)
				}
			}
			.listRowSeparator(.hidden)
	}
	
	func description(_ headline: Text, @ViewBuilder _ content: () -> some View) -> some View {
		VStack(alignment: .leading, spacing: 8) {
			headline
				.font(.title3.bold())
				.padding(.bottom, 4)
			
			content()
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(.vertical, 8)
	}
}

#if DEBUG
struct InAppStorefront_Previews: PreviewProvider {
    static var previews: some View {
		Form {
			InAppStorefront(store: .init())
		}
		.withToolbar()
		//.previewDevice("iPad Pro (11-inch) (4th generation)")
		
		ProFeaturesOverview()
			.withToolbar()
    }
}
#endif
