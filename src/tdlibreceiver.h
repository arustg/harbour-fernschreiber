/*
    Copyright (C) 2020 Sebastian J. Wolf

    This file is part of Fernschreiber.

    Fernschreiber is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Fernschreiber is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Fernschreiber. If not, see <http://www.gnu.org/licenses/>.
*/
#ifndef TDLIBRECEIVER_H
#define TDLIBRECEIVER_H

#include <QDebug>
#include <QThread>
#include <QJsonDocument>
#include <QJsonObject>
#include <td/telegram/td_json_client.h>

class TDLibReceiver : public QThread
{
    Q_OBJECT
    void run() Q_DECL_OVERRIDE {
        receiverLoop();
    }
public:
    explicit TDLibReceiver(void *tdLibClient, QObject *parent = nullptr);
    void setActive(const bool &active);

signals:
    void versionDetected(const QString &version);
    void authorizationStateChanged(const QString &authorizationState, const QVariantMap &authorizationStateData);
    void optionUpdated(const QString &optionName, const QVariant &optionValue);
    void connectionStateChanged(const QString &connectionState);
    void userUpdated(const QVariantMap &userInformation);
    void userStatusUpdated(const QString &userId, const QVariantMap &userStatusInformation);
    void fileUpdated(const QVariantMap &fileInformation);
    void newChatDiscovered(const QVariantMap &chatInformation);
    void unreadMessageCountUpdated(const QVariantMap &messageCountInformation);
    void unreadChatCountUpdated(const QVariantMap &chatCountInformation);
    void chatLastMessageUpdated(const QString &chatId, const QString &order, const QVariantMap &lastMessage);
    void chatOrderUpdated(const QString &chatId, const QString &order);
    void chatReadInboxUpdated(const QString &chatId, const QString &lastReadInboxMessageId, const int &unreadCount);
    void chatReadOutboxUpdated(const QString &chatId, const QString &lastReadOutboxMessageId);
    void basicGroupUpdated(const QString &groupId, const QVariantMap &groupInformation);
    void superGroupUpdated(const QString &groupId, const QVariantMap &groupInformation);
    void chatOnlineMemberCountUpdated(const QString &chatId, const int &onlineMemberCount);
    void messagesReceived(const QVariantList &messages);
    void newMessageReceived(const QString &chatId, const QVariantMap &message);
    void messageInformation(const QString &messageId, const QVariantMap &message);
    void messageSendSucceeded(const QString &messageId, const QString &oldMessageId, const QVariantMap &message);
    void activeNotificationsUpdated(const QVariantList notificationGroups);
    void notificationGroupUpdated(const QVariantMap notificationGroupUpdate);
    void notificationUpdated(const QVariantMap updatedNotification);
    void chatNotificationSettingsUpdated(const QString &chatId, const QVariantMap updatedChatNotificationSettings);
    void messageContentUpdated(const QString &chatId, const QString &messageId, const QVariantMap &newContent);
    void messagesDeleted(const QString &chatId, const QVariantList &messageIds);
    void chats(const QVariantMap &chats);

private:
    typedef void (TDLibReceiver::*Handler)(const QVariantMap &);

    QHash<QString, Handler> handlers;
    void *tdLibClient;
    bool isActive;

    void receiverLoop();
    void processReceivedDocument(const QJsonDocument &receivedJsonDocument);
    void processUpdateOption(const QVariantMap &receivedInformation);
    void processUpdateAuthorizationState(const QVariantMap &receivedInformation);
    void processUpdateConnectionState(const QVariantMap &receivedInformation);
    void processUpdateUser(const QVariantMap &receivedInformation);
    void processUpdateUserStatus(const QVariantMap &receivedInformation);
    void processUpdateFile(const QVariantMap &receivedInformation);
    void processFile(const QVariantMap &receivedInformation);
    void processUpdateNewChat(const QVariantMap &receivedInformation);
    void processUpdateUnreadMessageCount(const QVariantMap &receivedInformation);
    void processUpdateUnreadChatCount(const QVariantMap &receivedInformation);
    void processUpdateChatLastMessage(const QVariantMap &receivedInformation);
    void processUpdateChatOrder(const QVariantMap &receivedInformation);
    void processUpdateChatPosition(const QVariantMap &receivedInformation);
    void processUpdateChatReadInbox(const QVariantMap &receivedInformation);
    void processUpdateChatReadOutbox(const QVariantMap &receivedInformation);
    void processUpdateBasicGroup(const QVariantMap &receivedInformation);
    void processUpdateSuperGroup(const QVariantMap &receivedInformation);
    void processChatOnlineMemberCountUpdated(const QVariantMap &receivedInformation);
    void processMessages(const QVariantMap &receivedInformation);
    void processUpdateNewMessage(const QVariantMap &receivedInformation);
    void processMessage(const QVariantMap &receivedInformation);
    void processMessageSendSucceeded(const QVariantMap &receivedInformation);
    void processUpdateActiveNotifications(const QVariantMap &receivedInformation);
    void processUpdateNotificationGroup(const QVariantMap &receivedInformation);
    void processUpdateNotification(const QVariantMap &receivedInformation);
    void processUpdateChatNotificationSettings(const QVariantMap &receivedInformation);
    void processUpdateMessageContent(const QVariantMap &receivedInformation);
    void processUpdateDeleteMessages(const QVariantMap &receivedInformation);
    void processChats(const QVariantMap &receivedInformation);
};

#endif // TDLIBRECEIVER_H
