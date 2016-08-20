//
//  HTFileTransferConst.h
//  HTFileDownloader
//
//  Created by 小丸子 on 27/5/2016.
//  Copyright © 2016 hehui. All rights reserved.
//

#ifndef HTFileTransferConst_h
#define HTFileTransferConst_h

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, HTFileTransferState)
{
    HTFileTransferStateNone = 0,
    HTFileTransferStateReady,   //
    HTFileTransferStateWaiting,     //等待
    HTFileTransferStateTransfering, //正在transfer
    HTFileTransferStatePaused,      //任务中止
    HTFileTransferStateCancelled,   //任务被取消
    HTFileTransferStateDone,        //任务成功结束
    HTFileTransferStateFailed       //任务失败
};

#endif /* HTFileTransferConst_h */
