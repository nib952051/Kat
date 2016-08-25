#include "dialogslistmodel.h"

DialogsListModel::DialogsListModel(QObject *parent) : QAbstractListModel(parent)
{}

int DialogsListModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return _dialogsIds.size();
}

QVariant DialogsListModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid()) return QVariant();

    Dialog *dialog = _dialogs[_dialogsIds.at(index.row())];
    qint64 profileId = dialog->lastMessage()->userId();
    qint64 chatId = dialog->lastMessage()->chatId();

    switch (role) {
    case IdRole:
        if (dialog->isChat()) return QVariant(dialog->lastMessage()->chatId());
        return QVariant(dialog->lastMessage()->userId());

    case AvatarRole: {
        QStringList avatarUrls;
        if (dialog->isChat()) {
            if (!_chats.contains(chatId)) return QVariant();
            if (!_chats[chatId]->photo().isEmpty()) avatarUrls.append(_chats[chatId]->photo());
            else {
                for (int index = 0; index < _chats[chatId]->users().size() && index < 4; ++index) {
                    qint64 userId = _chats[chatId]->users().at(index).toInt();
                    if (_profiles.contains(userId)) avatarUrls.append(_profiles[userId]->photo50());
                }
            }
            return QVariant(avatarUrls);
        } else {
            if (!_profiles.contains(profileId)) return QVariant();
            avatarUrls.append(_profiles[profileId]->photo50());
            return QVariant(avatarUrls);
        }
    }

    case TitleRole:
        if (dialog->isChat()) {
            if (!_chats.contains(chatId)) return QVariant();
            return QVariant(_chats[chatId]->title());
        } else {
            if (!_profiles.contains(profileId)) return QVariant();
            return QVariant(_profiles[profileId]->firstName() + " " + _profiles[profileId]->lastName());
        }

    case PreviewRole: {
        QString attachments = dialog->lastMessage()->hasAttachments() ? "[ 📎 ] " : "";
        return QVariant(QString("%1%2").arg(attachments).arg(dialog->lastMessage()->body()));
    }

    case UnreadRole:
        return QVariant(dialog->unread());

    case IsChatRole:
        return QVariant(dialog->isChat());

    case IsOnlineRole:
        if (dialog->isChat()) return QVariant();
        else {
            if (!_profiles.contains(profileId)) return QVariant();
            return QVariant(_profiles[profileId]->online());
        }

    case IsOutRole:
        return QVariant(dialog->lastMessage()->out());

    default:
        return QVariant();
    }
}

QHash<int, QByteArray> DialogsListModel::roleNames() const {
    QHash<int, QByteArray> roles = QAbstractListModel::roleNames();
    roles[IdRole] = "id";
    roles[AvatarRole] = "avatar";
    roles[TitleRole] = "dialogTitle";
    roles[PreviewRole] = "preview";
    roles[UnreadRole] = "unread";
    roles[IsChatRole] = "isChat";
    roles[IsOnlineRole] = "online";
    roles[IsOutRole] = "isOut";
    return roles;
}

void DialogsListModel::add(Dialog *dialog) {
    qint64 id = dialog->isChat() ? dialog->lastMessage()->chatId() : dialog->lastMessage()->userId();
    if (_dialogs.contains(id)) return;

    beginInsertRows(QModelIndex(), _dialogsIds.size(), _dialogsIds.size());
    _dialogsIds.append(id);
    _dialogs[id] = dialog;
    endInsertRows();

    QModelIndex index = createIndex(0, 0, static_cast<void *>(0));
    emit dataChanged(index, index);
}

void DialogsListModel::addProfile(Friend *profile) {
    if (_profiles.contains(profile->id())) return;
    _profiles[profile->id()] = profile;

    QModelIndex startIndex = createIndex(0, 0, static_cast<void *>(0));
    QModelIndex endIndex = createIndex(_dialogsIds.size(), 0, static_cast<void *>(0));
    emit dataChanged(startIndex, endIndex);
}

void DialogsListModel::addChat(Chat *chat) {
    if (_chats.contains(chat->id())) return;
    _chats[chat->id()] = chat;

    QModelIndex startIndex = createIndex(0, 0, static_cast<void *>(0));
    QModelIndex endIndex = createIndex(_dialogsIds.size(), 0, static_cast<void *>(0));
    emit dataChanged(startIndex, endIndex);
}

void DialogsListModel::readMessages(qint64 peerId, qint64 localId, bool out) {
    if (!_dialogs.contains(peerId)) return;
    if (_dialogs[peerId]->lastMessage()->id() == localId && _dialogs[peerId]->lastMessage()->out() == out) {
        _dialogs[peerId]->setUnread(false);
        _dialogs[peerId]->lastMessage()->setReadState(true);
        QModelIndex index = createIndex(_dialogsIds.indexOf(peerId), _dialogsIds.indexOf(peerId), static_cast<void *>(0));
        emit dataChanged(index, index);
    }
}

void DialogsListModel::update(Message *message) {
    if (_dialogsIds.isEmpty()) return;

    qint64 id = 0;
    if (message->chat()) id = message->chatId();
    else id = message->userId();

    if (_dialogs.contains(id)) {
        if (_dialogsIds.indexOf(id) != 0) {
            beginMoveRows(QModelIndex(), _dialogsIds.indexOf(id), _dialogsIds.indexOf(id), QModelIndex(), 0);
            _dialogsIds.removeOne(id);
            _dialogsIds.insert(0, id);
            endMoveRows();
        }
    } else {
        beginInsertRows(QModelIndex(), 0, 0);
        _dialogsIds.insert(0, id);
        _dialogs[id] = new Dialog();
        _dialogs[id]->setIsChat(message->chatId() != 2000000000);
        endInsertRows();
    }
    _dialogs[id]->setUnread(!message->readState());
    _dialogs[id]->setLastMessage(message);

    QModelIndex startIndex = createIndex(0, 0, static_cast<void *>(0));
    QModelIndex endIndex = createIndex(_dialogsIds.size(), 0, static_cast<void *>(0));
    emit dataChanged(startIndex, endIndex);
}

qint64 DialogsListModel::size() const {
    return _dialogsIds.size();
}

