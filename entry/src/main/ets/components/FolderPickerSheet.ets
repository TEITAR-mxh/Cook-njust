import { AppColors } from '../constants/AppColors'
import { FolderItem } from '../store/CookPreferences'

@Component
export struct FolderPickerSheet {
  @Prop folders: FolderItem[] = []
  onAddToFolder?: (folderId: string) => void
  onCreateAndAdd?: (name: string) => void
  onClose?: () => void

  @State showCreateInput: boolean = false
  @State newFolderName: string = ''

  build() {
    Column({ space: 0 }) {
      // 标题栏
      Row() {
        Text('加入收藏夹')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1F2937')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('✕')
          .fontSize(18)
          .fontColor('#9CA3AF')
          .padding(8)
          .onClick(() => { if (this.onClose) this.onClose() })
      }
      .width('100%')
      .padding({ left: 16, right: 8, top: 20, bottom: 12 })

      Divider().color('#F3F4F6').strokeWidth(1)

      // 收藏夹列表
      Scroll() {
        Column({ space: 0 }) {
          if (this.folders.length === 0 && !this.showCreateInput) {
            Column({ space: 8 }) {
              Text('📂').fontSize(40)
              Text('还没有收藏夹').fontSize(14).fontColor('#9CA3AF')
            }
            .width('100%')
            .padding({ top: 32, bottom: 32 })
            .justifyContent(FlexAlign.Center)
          }

          ForEach(this.folders, (folder: FolderItem) => {
            Row({ space: 12 }) {
              Text('📁').fontSize(28)
              Column({ space: 2 }) {
                Text(folder.name)
                  .fontSize(15)
                  .fontColor('#1F2937')
                  .fontWeight(FontWeight.Medium)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(`${folder.recipeIds.length} 道菜`)
                  .fontSize(12)
                  .fontColor('#9CA3AF')
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)

              Text('›').fontSize(18).fontColor('#D1D5DB')
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 14, bottom: 14 })
            .onClick(() => {
              if (this.onAddToFolder) this.onAddToFolder(folder.id)
            })

            Divider().color('#F9FAFB').strokeWidth(1).margin({ left: 72 })
          }, (f: FolderItem) => f.id)

          // 新建收藏夹输入区
          if (this.showCreateInput) {
            Column({ space: 12 }) {
              Row({ space: 12 }) {
                TextInput({ placeholder: '收藏夹名称', text: this.newFolderName })
                  .layoutWeight(1)
                  .fontSize(15)
                  .backgroundColor('#F9FAFB')
                  .borderRadius(10)
                  .padding({ left: 14, right: 14, top: 10, bottom: 10 })
                  .onChange((v: string) => { this.newFolderName = v })
              }.width('100%').padding({ left: 20, right: 20 })

              Row({ space: 12 }) {
                Text('取消')
                  .fontSize(15)
                  .fontColor('#6B7280')
                  .layoutWeight(1)
                  .textAlign(TextAlign.Center)
                  .padding({ top: 12, bottom: 12 })
                  .backgroundColor('#F3F4F6')
                  .borderRadius(10)
                  .onClick(() => {
                    this.showCreateInput = false
                    this.newFolderName = ''
                  })

                Text('创建并加入')
                  .fontSize(15)
                  .fontColor(Color.White)
                  .fontWeight(FontWeight.Medium)
                  .layoutWeight(1)
                  .textAlign(TextAlign.Center)
                  .padding({ top: 12, bottom: 12 })
                  .backgroundColor(AppColors.BRAND_COLOR)
                  .borderRadius(10)
                  .onClick(() => {
                    const name = this.newFolderName.trim()
                    if (name.length > 0 && this.onCreateAndAdd) {
                      this.onCreateAndAdd(name)
                    }
                  })
              }.width('100%').padding({ left: 20, right: 20 })
            }.padding({ top: 16, bottom: 8 })
          }
        }
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // 底部：新建收藏夹按钮
      if (!this.showCreateInput) {
        Column() {
          Divider().color('#F3F4F6').strokeWidth(1)
          Row({ space: 8 }) {
            Text('+').fontSize(18).fontColor(AppColors.BRAND_COLOR).fontWeight(FontWeight.Bold)
            Text('新建收藏夹').fontSize(15).fontColor(AppColors.BRAND_COLOR).fontWeight(FontWeight.Medium)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 16, bottom: 16 })
          .onClick(() => {
            this.showCreateInput = true
            this.newFolderName = ''
          })
        }
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
    .borderRadius({ topLeft: 20, topRight: 20 })
  }
}
