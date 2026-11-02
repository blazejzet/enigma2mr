//
//  ScrollableSectionCollectionViewLayout.swift
//  EnigmaTV
//
//  Created by Blazej Zyglarski on 26/05/2020.
//  Copyright © 2020 Blazej Zyglarski. All rights reserved.
//

import UIKit

class ScrollableSectionCollectionViewLayout {
    class func create()->UICollectionViewCompositionalLayout
    {
        let layout = UICollectionViewCompositionalLayout { (sectionIndex: Int,
          layoutEnvironment: NSCollectionLayoutEnvironment)
            -> NSCollectionLayoutSection? in
          let isWideView = layoutEnvironment.container.effectiveContentSize.width > 500

          //let sectionLayoutKind = Section.allCases[sectionIndex]
          //switch (sectionLayoutKind) {
          //case .featuredAlbums: return self.generateFeaturedAlbumsLayout(
          //  isWide: isWideView
            //case .sharedAlbums:
           return ScrollableSectionCollectionViewLayout.generateSharedlbumsLayout()
          //case .myAlbums: return self.generateMyAlbumsLayout(isWide: isWideView)
          //}
        }

        return layout
    }
    
    class func generateSharedlbumsLayout() -> NSCollectionLayoutSection {
      let itemSize = NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .fractionalWidth(1.0))
        
      let item = NSCollectionLayoutItem(layoutSize: itemSize)

      let groupSize = NSCollectionLayoutSize(
        widthDimension: .absolute(420),
        heightDimension: .absolute(320))
      let group = NSCollectionLayoutGroup.vertical(
        layoutSize: groupSize,
        subitem: item,
        count: 1)
      group.contentInsets = NSDirectionalEdgeInsets(
        top: 5,
        leading: 5,
        bottom: 5,
        trailing: 5)

      let headerSize = NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1.0),
        heightDimension: .estimated(44))
      let sectionHeader = NSCollectionLayoutBoundarySupplementaryItem(
        layoutSize: headerSize,
        elementKind: "section-header-element-kind",//,, //AlbumsViewController.sectionHeaderElementKind
        alignment: .top)

      let section = NSCollectionLayoutSection(group: group)
      section.boundarySupplementaryItems = [sectionHeader]
      section.orthogonalScrollingBehavior = .groupPaging

      return section
    }
}

