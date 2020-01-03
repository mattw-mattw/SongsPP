//
//  TransferHandler.swift
//  just-exploring-3
//
//  Created by Admin on 28/10/2019.
//  Copyright © 2019 mattweir. All rights reserved.
//

import Foundation
import UIKit

class TransferHandler: NSObject, MEGATransferDelegate {
    
    func onTransferStart(_ api: MEGASdk, transfer: MEGATransfer) {
    }
    
    func onTransferUpdate(_ api: MEGASdk, transfer: MEGATransfer) {
        let percent = NSNumber(value: transfer.transferredBytes.floatValue / transfer.totalBytes.floatValue);
        app().downloadProgress(nodeHandle: transfer.nodeHandle, percent: percent)
    }
    
    func onTransferFinish(_ api: MEGASdk, transfer request: MEGATransfer, error: MEGAError) {
        if (error.type.rawValue == 0)
        {
            app().fileArrived(handle: request.nodeHandle);
        }
        else
        {
            app().fileFailed(handle: request.nodeHandle);
        }
    }
}
