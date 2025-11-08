import AppKit
import SwiftUI

struct EffectGalleryView: View {
  @ObservedObject var viewModel: EffectGalleryViewModel
  @Environment(\.dismiss) var dismiss

  // 固定8列，卡片更小更紧凑
  let columns = [
    GridItem(.fixed(130), spacing: 10),
    GridItem(.fixed(130), spacing: 10),
    GridItem(.fixed(130), spacing: 10),
    GridItem(.fixed(130), spacing: 10),
    GridItem(.fixed(130), spacing: 10),
    GridItem(.fixed(130), spacing: 10),
    GridItem(.fixed(130), spacing: 10),
    GridItem(.fixed(130), spacing: 10),
  ]

  var body: some View {
    VStack(spacing: 0) {
      // 自定义标题栏
      HStack {
        Text("Effect Gallery")
          .font(.title2)
          .fontWeight(.semibold)

        Spacer()

        Button("Close") {
          dismiss()
        }
        .keyboardShortcut(.escape, modifiers: [])
      }
      .padding()
      .background(Color(NSColor.windowBackgroundColor))

      Divider()

      // 网格内容
      ScrollView {
        LazyVGrid(columns: columns, spacing: 12, pinnedViews: []) {
          ForEach(Array(viewModel.effects.enumerated()), id: \.offset) { index, effect in
            EffectThumbnailView(
              effect: effect,
              thumbnail: viewModel.getThumbnail(for: index),
              isSelected: index == viewModel.currentIndex
            )
            .onTapGesture {
              viewModel.selectEffect(at: index)
            }
            .id(index)
          }
        }
        .padding(16)
        .drawingGroup()
      }
    }
    .frame(minWidth: 1120, minHeight: 600)
  }
}

struct EffectThumbnailView: View {
  let effect: VisualEffect
  let thumbnail: NSImage?
  let isSelected: Bool

  @State private var isHovering = false

  var body: some View {
    ZStack {
      // 主卡片内容
      if let thumbnail = thumbnail {
        Image(nsImage: thumbnail)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 130, height: 98)  // 4:3 比例
          .clipped()
      } else {
        Rectangle()
          .fill(Color.black)
          .frame(width: 130, height: 98)
          .overlay(
            Text("...")
              .foregroundColor(.gray.opacity(0.5))
              .font(.system(size: 9))
          )
      }

      // 底部标题栏（在卡片内部）
      VStack {
        Spacer()

        if !isHovering {
          Text(effect.displayName)
            .font(.system(size: 10, weight: .medium))
            .lineLimit(1)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(
              Rectangle()
                .fill(Color.black.opacity(0.75))
            )
        }
      }
      .frame(width: 130, height: 98)

      // 选中边框（金色）
      if isSelected {
        RoundedRectangle(cornerRadius: 6)
          .stroke(Color(red: 1.0, green: 0.84, blue: 0.0), lineWidth: 2.5)  // 金色
          .frame(width: 130, height: 98)
      }
    }
    .frame(width: 130, height: 98)
    .cornerRadius(6)
    .shadow(
      color: isSelected
        ? Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.4) : Color.black.opacity(0.2),
      radius: isSelected ? 6 : 3, x: 0, y: 2
    )
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.15)) {
        isHovering = hovering
      }
    }
  }
}

#Preview {
  EffectGalleryView(viewModel: EffectGalleryViewModel())
}
