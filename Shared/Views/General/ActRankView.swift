import SwiftUI
import ValorantAPI
import HandyOperators
import CGeometry

struct ActRankView: View {
	let seasonInfo: CareerSummary.SeasonInfo
	var isIcon = true
	var isShowingAllWins = false
	
	@Environment(\.assets) private var assets
	
	var body: some View {
		let idealSize = isIcon ? 80 : 160.0
		let standardRowCount = isIcon ? 3 : 7
		
		ZStack {
			let actInfo = assets?.seasons.acts[seasonInfo.seasonID]
			let border = actInfo?.borders.last { seasonInfo.winCount >= $0.winsRequired }
			if let border = border, let winsByTier = seasonInfo.winsByTier {
				let container = isIcon
					? (border.icon ?? actInfo?.borders.lazy.compactMap(\.icon).first) // show icon even when not qualified for border
					: border.fullImage
				container?.imageOrPlaceholder()
				
				Canvas { context, size in
					typealias ResolvedImage = GraphicsContext.ResolvedImage
					typealias TierTriangles = (upwards: ResolvedImage?, downwards: ResolvedImage?)
					
					let triangleTiers = winsByTier
						.sorted(on: \.key)
						.reversed()
						.lazy // lazily resolve images—essentially waits until a certain tier's triangles are requested to resolve its images
						.filter { $0.key > 0 } // only ones we can actually display (important for auto-fitting)
						.map { [context] tier, count -> (TierTriangles, Int) in
							let tierInfo = assets?.seasons.tierInfo(number: tier, in: actInfo)
							let upwards = (tierInfo?.rankTriangleUpwards?.imageIfLoaded).map(context.resolve)
							let downwards = (tierInfo?.rankTriangleDownwards?.imageIfLoaded).map(context.resolve)
							return ((upwards, downwards), count)
						}
						.flatMap(repeatElement(_:count:))
					
					let rowCountToFitAll = Int(Double(triangleTiers.count).squareRoot().rounded(.up))
					let rowCount = isShowingAllWins ? rowCountToFitAll : standardRowCount
					
					// the images don't quite have this aspect ratio, but we're rescaling them anyway, so we may as well make them ideal
					let triangleRatio: CGFloat = sin(.pi / 3)
					// triangles should not be scaled about (0.5, 0.5) but rather a point 2/3 of the way down
					let triangleCenter = CGSize(width: 0.5, height: 2/3)
					
					context.scaleBy(x: size.width, y: size.height)
					
					do { // fit to container
						let width = 0.6
						let height = width * triangleRatio
						let sizeDifference = CGVector(dx: 1 - width, dy: 1 - height)
						let center = sizeDifference * triangleCenter
						let yOffset = isIcon ? -0.053 : -0.066 // because of course it's not centered
						context.translateBy(x: center.dx, y: center.dy + yOffset)
						context.scaleBy(x: width, y: height)
					}
					
					do { // map unit square to top triangle
						let triangleHeight = 1 / CGFloat(rowCount)
						context.translateBy(x: 0.5, y: 0)
						context.scaleBy(x: triangleHeight, y: triangleHeight)
					}
					
					var remainingTiers = triangleTiers[...] // constant-time prefix removal
					for rowNumber in 0..<rowCount {
						guard !remainingTiers.isEmpty else { break } // all done
						
						let tierCount = rowNumber * 2 + 1
						let tiers = remainingTiers.prefix(tierCount)
						remainingTiers = remainingTiers.dropFirst(tierCount)
						
						var context = context
						context.translateBy(x: 0, y: CGFloat(rowNumber))
						
						for (index, tier) in tiers.enumerated() {
							let shouldPointUpwards = index % 2 == 0
							let triangle = shouldPointUpwards ? tier.upwards : tier.downwards
							guard let triangle = triangle else { continue }
							
							var context = context
							context.translateBy(x: CGFloat(index - rowNumber - 1) * 0.5, y: 0)
							
							context.draw(triangle, in: CGRect(origin: .zero, size: .one))
						}
					}
				}
			}
		}
		.aspectRatio(1, contentMode: .fit)
		.frame(idealWidth: idealSize, idealHeight: idealSize)
	}
}

#if DEBUG
struct ActRankView_Previews: PreviewProvider {
	static let assets = AssetManager.forPreviews.assets!
	static let currentAct = assets.seasons.currentAct()!
	static let previousAct = assets.seasons.actBefore(currentAct)!
	
	static let bySeason = PreviewData.summary.competitiveInfo!.bySeason!
	
	static var previews: some View {
		HStack(alignment: .bottom) {
			ForEach(assets.seasons.actsInOrder) { act in
				preview(for: act)
					.padding()
			}
		}
		.inEachColorScheme()
		.fixedSize()
		.previewLayout(.sizeThatFits)
		
		ActRankView(seasonInfo: bySeason[currentAct.id]!, isShowingAllWins: true)
			.preferredColorScheme(.dark)
	}
	
	static func preview(for act: Act) -> some View {
		VStack {
			if let seasonInfo = bySeason[act.id] {
				ActRankView(seasonInfo: seasonInfo, isIcon: true)
				ActRankView(seasonInfo: seasonInfo, isIcon: false)
			}
			
			Text(act.nameWithEpisode)
				.font(.caption.smallCaps())
		}
	}
}
#endif
