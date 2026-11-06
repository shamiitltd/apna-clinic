/**
 * Apna Clinic - Drive Repository
 * Google Drive file and folder operations
 */

var DriveRepository = {
  createSpreadsheetInFolder: function(title, folderId) {
    var ss = SpreadsheetApp.create(title);
    var file = DriveApp.getFileById(ss.getId());

    if (folderId) {
      try {
        var folder = DriveApp.getFolderById(folderId);
        folder.addFile(file);
        DriveApp.getRootFolder().removeFile(file);
      } catch (e) {
        // Fall back to keeping in root folder if folderId invalid or inaccessible
      }
    }
    return ss;
  },

  findFileByName: function(title, folderId) {
    var iterator;
    if (folderId) {
      try {
        var folder = DriveApp.getFolderById(folderId);
        iterator = folder.getFilesByName(title);
      } catch (e) {
        iterator = DriveApp.getFilesByName(title);
      }
    } else {
      iterator = DriveApp.getFilesByName(title);
    }

    if (iterator.hasNext()) {
      return iterator.next();
    }
    return null;
  }
};

