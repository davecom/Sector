//
//  PreviewSplitViewController.swift
//  Sector
//
//  Created by David Kopec on 8/23/26.
//

import Cocoa
import HFSKit

class PreviewSplitViewController: NSSplitViewController {
    
    var dataForkViewController: DataForkViewController? {
        return splitViewItems.first?.viewController as? DataForkViewController
    }
    
    var resourceForkViewController: ResourceForkViewController? {
        return splitViewItems.last?.viewController as? ResourceForkViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    func populate(dataFork: Data, resourceFork: [Resource]) {
        dataForkViewController?.data = dataFork
        resourceForkViewController?.resources = resourceFork
    }
}
