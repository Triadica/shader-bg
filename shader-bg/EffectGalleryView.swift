import AppKit
import SwiftUI

struct EffectGalleryView: View {
  @ObservedObject var viewModel: EffectGalleryViewModel
  @Environment(\.dismiss) var dismiss

  // 使用自适应网格，根据窗口宽度自动调整列数
  // minimum: 130 表示每个卡片最小宽度为 130
  // maximum: 130 表示每个卡片最大宽度也为 130，这样卡片大小固定，只调整数量
  let columns = [
    GridItem(.adaptive(minimum: 130, maximum: 130), spacing: 10)
  ]

  var body: some View {
    VStack(spacing: 0) {
      // 网格内容
      ScrollView {
        LazyVGrid(columns: columns, spacing: 12, pinnedViews: []) {
          ForEach(Array(viewModel.effects.enumerated()), id: \.offset) { index, effect in
            EffectThumbnailView(
              effect: effect,
              thumbnail: viewModel.getThumbnail(for: index),
              isSelected: index == viewModel.currentIndex,
              isGenerating: viewModel.generatingThumbnails.contains(index),
              gpuUsageText: viewModel.getGPUUsageText(for: index),
              onRefresh: {
                viewModel.refreshThumbnail(for: index)
              }
            )
            .onTapGesture {
              viewModel.selectEffect(at: index)
            }
            .id(index)
          }
        }
        .padding(16)
      }
    }
    .frame(minWidth: 400, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
  }
}

struct EffectThumbnailView: View {
  let effect: VisualEffect
  let thumbnail: NSImage?
  let isSelected: Bool
  let isGenerating: Bool  // 是否正在生成缩略图
  let gpuUsageText: String?  // GPU开销文本
  let onRefresh: () -> Void  // 刷新回调

  @State private var isHovering = false

  var body: some View {
    ZStack {
      // 主卡片内容
      if isGenerating {
        // 生成中：显示灰色占位符
        Rectangle()
          .fill(Color.gray.opacity(0.3))
          .frame(width: 130, height: 98)
          .overlay(
            Text("Generating...")
              .foregroundColor(.white.opacity(0.6))
              .font(.system(size: 9))
          )
      } else if let thumbnail = thumbnail {
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

      // 刷新按钮（右上角，仅在有缩略图且悬停时显示）
      if thumbnail != nil && !isGenerating {
        VStack {
          HStack {
            Spacer()
            Button(action: onRefresh) {
              Image(systemName: "arrow.clockwise")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1.0 : 0.0)
            .padding(4)
          }
          Spacer()
        }
        .frame(width: 130, height: 98)
      }

      // 底部信息栏（在卡片内部）
      VStack {
        Spacer()

        // 显示逻辑：
        // 1. 没有截图时（thumbnail == nil）：始终显示文字
        // 2. 有截图时：只在悬停时显示文字
        if thumbnail == nil || isHovering {
          VStack(spacing: 2) {
            Text(effect.displayName)
              .font(.system(size: 10, weight: .medium))
              .lineLimit(1)
              .foregroundColor(.white)
              .frame(maxWidth: .infinity)

            // GPU开销显示
            if let gpuText = gpuUsageText {
              Text(gpuText)
                .font(.system(size: 8))
                .foregroundColor(.green.opacity(0.9))
            }
          }
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
