const express = require('express');
const Chemical = require('../models/Chemical');
const Equipment = require('../models/Equipment');
const Borrowing = require('../models/Borrowing');
const PDFDocument = require('pdfkit');
const createCsvWriter = require('csv-writer').createObjectCsvWriter;
const { authenticateToken, requireAdminOrTechnician } = require('../middleware/auth');
const router = express.Router();

// Get monthly report
router.get('/monthly', authenticateToken, requireAdminOrTechnician, async (req, res) => {
  try {
    console.log('Generating monthly report for user:', req.user);
    
    // Safely get data with error handling
    let expiringChemicals = [];
    let lowStockChemicals = [];
    let dueEquipment = [];
    let overdueBorrowings = [];
    
    try {
      expiringChemicals = await Chemical.getExpiringSoon();
      console.log('Found expiring chemicals:', expiringChemicals.length);
    } catch (error) {
      console.warn('Could not get expiring chemicals:', error.message);
    }
    
    try {
      lowStockChemicals = await Chemical.getLowStock();
      console.log('Found low stock chemicals:', lowStockChemicals.length);
    } catch (error) {
      console.warn('Could not get low stock chemicals:', error.message);
    }
    
    try {
      dueEquipment = await Equipment.getDueForMaintenance();
      console.log('Found due equipment:', dueEquipment.length);
    } catch (error) {
      console.warn('Could not get due equipment:', error.message);
    }
    
    try {
      overdueBorrowings = await Borrowing.getOverdue();
      console.log('Found overdue borrowings:', overdueBorrowings.length);
    } catch (error) {
      console.warn('Could not get overdue borrowings:', error.message);
    }
    
    // Get counts safely using proper count methods
    let totalChemicals = 0;
    let totalEquipment = 0;
    let activeBorrowings = 0;
    let pendingBorrowings = 0;
    let overdueBorrowingsCount = overdueBorrowings.length;
    
    try {
      // Use count() method with proper where clause for better performance
      totalChemicals = await Chemical.count({
        where: {
          deleted_at: null  // Exclude soft-deleted records
        }
      });
      console.log('Total chemicals count:', totalChemicals);
    } catch (error) {
      console.warn('Could not get total chemicals count:', error.message);
      // Fallback to findAll if count fails
      try {
        totalChemicals = (await Chemical.findAll({
          where: { deleted_at: null }
        })).length;
      } catch (fallbackError) {
        console.warn('Fallback chemical count also failed:', fallbackError.message);
      }
    }
    
    try {
      // Use count() method with proper where clause for better performance
      totalEquipment = await Equipment.count({
        where: {
          deleted_at: null  // Exclude soft-deleted records
        }
      });
      console.log('Total equipment count:', totalEquipment);
    } catch (error) {
      console.warn('Could not get total equipment count:', error.message);
      // Fallback to findAll if count fails
      try {
        totalEquipment = (await Equipment.findAll({
          where: { deleted_at: null }
        })).length;
      } catch (fallbackError) {
        console.warn('Fallback equipment count also failed:', fallbackError.message);
      }
    }
    
    try {
      // Use count() method with proper where clause
      activeBorrowings = await Borrowing.count({
        where: {
          status: 'approved',
          deleted_at: null
        }
      });
      console.log('Active borrowings count:', activeBorrowings);
    } catch (error) {
      console.warn('Could not get active borrowings count:', error.message);
      // Fallback to findAll if count fails
      try {
        activeBorrowings = (await Borrowing.findAll({
          where: { 
            status: 'approved',
            deleted_at: null 
          }
        })).length;
      } catch (fallbackError) {
        console.warn('Fallback active borrowings count also failed:', fallbackError.message);
      }
    }
    
    try {
      // DEBUG: Check what status values actually exist in your database
      const allBorrowings = await Borrowing.findAll({
        attributes: ['status'],
        where: { deleted_at: null },
        raw: true
      });
      
      const statusCounts = {};
      allBorrowings.forEach(borrowing => {
        const status = borrowing.status;
        statusCounts[status] = (statusCounts[status] || 0) + 1;
      });
      
      console.log('=== BORROWING STATUS DEBUG ===');
      console.log('All borrowing statuses in database:', statusCounts);
      console.log('Total borrowings found:', allBorrowings.length);
      console.log('==============================');
      
      // Try different possible status values for pending
      pendingBorrowings = await Borrowing.count({
        where: {
          status: 'pending',
          deleted_at: null
        }
      });
      console.log('Pending borrowings count (looking for "pending"):', pendingBorrowings);
      
      // If pending count is 0, try other common status values
      if (pendingBorrowings === 0) {
        const submittedCount = await Borrowing.count({
          where: { status: 'submitted', deleted_at: null }
        });
        console.log('Submitted borrowings count (looking for "submitted"):', submittedCount);
        
        const requestedCount = await Borrowing.count({
          where: { status: 'requested', deleted_at: null }
        });
        console.log('Requested borrowings count (looking for "requested"):', requestedCount);
        
        const awaitingCount = await Borrowing.count({
          where: { status: 'awaiting_approval', deleted_at: null }
        });
        console.log('Awaiting approval count (looking for "awaiting_approval"):', awaitingCount);
        
        // Use the first non-zero count we find, or check if any of these exist in statusCounts
        if (statusCounts['submitted'] > 0) {
          pendingBorrowings = submittedCount;
          console.log('Using "submitted" status for pending count:', pendingBorrowings);
        } else if (statusCounts['requested'] > 0) {
          pendingBorrowings = requestedCount;
          console.log('Using "requested" status for pending count:', pendingBorrowings);
        } else if (statusCounts['awaiting_approval'] > 0) {
          pendingBorrowings = awaitingCount;
          console.log('Using "awaiting_approval" status for pending count:', pendingBorrowings);
        } else {
          // Check if there are any statuses that aren't 'approved' and use them as pending
          const nonApprovedStatuses = Object.keys(statusCounts).filter(status => 
            status !== 'approved' && status !== 'completed' && status !== 'returned' && status !== 'rejected'
          );
          
          if (nonApprovedStatuses.length > 0) {
            const firstPendingStatus = nonApprovedStatuses[0];
            pendingBorrowings = statusCounts[firstPendingStatus];
            console.log(`Using "${firstPendingStatus}" status for pending count:`, pendingBorrowings);
          }
        }
      }
      
    } catch (error) {
      console.warn('Could not get pending borrowings count:', error.message);
      pendingBorrowings = 0;
    }
    
    const report = {
      summary: {
        totalChemicals: totalChemicals,
        totalEquipment: totalEquipment,
        activeBorrowings: activeBorrowings,
        pendingBorrowings: pendingBorrowings,
        overdueBorrowings: overdueBorrowingsCount
      },
      expiringChemicals,
      lowStockChemicals,
      dueEquipment,
      overdueBorrowings
    };
    
    console.log('Monthly report summary:', report.summary);
    console.log('Monthly report generated successfully');
    res.json(report);
  } catch (error) {
    console.error('Error generating monthly report:', error);
    res.status(500).json({ error: 'Failed to generate report: ' + error.message });
  }
});

// Export report as PDF
router.get('/pdf', authenticateToken, requireAdminOrTechnician, async (req, res) => {
  try {
    const expiringChemicals = await Chemical.getExpiringSoon();
    const lowStockChemicals = await Chemical.getLowStock();
    const dueEquipment = await Equipment.getDueForMaintenance();
    const overdueBorrowings = await Borrowing.getOverdue();
    
    // Use the same logic as monthly report for consistent counts
    let pendingBorrowings = await Borrowing.count({ where: { status: 'pending', deleted_at: null } });
    
    // If no pending found, try other status values
    if (pendingBorrowings === 0) {
      const allBorrowings = await Borrowing.findAll({
        attributes: ['status'],
        where: { deleted_at: null },
        raw: true
      });
      
      const statusCounts = {};
      allBorrowings.forEach(borrowing => {
        const status = borrowing.status;
        statusCounts[status] = (statusCounts[status] || 0) + 1;
      });
      
      // Use same logic as monthly report
      if (statusCounts['submitted'] > 0) {
        pendingBorrowings = statusCounts['submitted'];
      } else if (statusCounts['requested'] > 0) {
        pendingBorrowings = statusCounts['requested'];
      } else if (statusCounts['awaiting_approval'] > 0) {
        pendingBorrowings = statusCounts['awaiting_approval'];
      }
    }
    
    const report = {
      summary: {
        totalChemicals: await Chemical.count({ where: { deleted_at: null } }),
        totalEquipment: await Equipment.count({ where: { deleted_at: null } }),
        activeBorrowings: await Borrowing.count({ where: { status: 'approved', deleted_at: null } }),
        pendingBorrowings: pendingBorrowings,
        overdueBorrowings: overdueBorrowings.length
      },
      expiringChemicals,
      lowStockChemicals,
      dueEquipment,
      overdueBorrowings
    };
    
    const doc = new PDFDocument();
    const filename = `chemlab-report-${new Date().toISOString().split('T')[0]}.pdf`;
    
    res.setHeader('Content-disposition', `attachment; filename="${filename}"`);
    res.setHeader('Content-type', 'application/pdf');
    
    doc.pipe(res);
    
    doc.fontSize(20).text('ChemLab Management System - Monthly Report', { align: 'center' });
    doc.moveDown();
    
    doc.fontSize(14).text(`Report Date: ${new Date().toLocaleDateString()}`);
    doc.moveDown();
    
    doc.fontSize(16).text('Summary:');
    doc.fontSize(12).text(`Total Chemicals: ${report.summary.totalChemicals}`);
    doc.text(`Total Equipment: ${report.summary.totalEquipment}`);
    doc.text(`Active Borrowings: ${report.summary.activeBorrowings}`);
    doc.text(`Pending Borrowings: ${report.summary.pendingBorrowings}`);
    doc.text(`Overdue Borrowings: ${report.summary.overdueBorrowings}`);
    doc.moveDown();
    
    doc.fontSize(16).text('Expiring Chemicals:');
    if (report.expiringChemicals.length === 0) {
      doc.fontSize(12).text('No expiring chemicals.');
    } else {
      report.expiringChemicals.forEach(chem => {
        doc.fontSize(12).text(`• ${chem.name} - Expires: ${new Date(chem.expiry_date).toLocaleDateString()}`);
      });
    }
    doc.moveDown();
    
    doc.fontSize(16).text('Low Stock Chemicals:');
    if (report.lowStockChemicals.length === 0) {
      doc.fontSize(12).text('No low stock chemicals.');
    } else {
      report.lowStockChemicals.forEach(chem => {
        doc.fontSize(12).text(`• ${chem.name} - Quantity: ${chem.quantity} ${chem.unit}`);
      });
    }
    doc.moveDown();
    
    doc.fontSize(16).text('Equipment Due for Maintenance:');
    if (report.dueEquipment.length === 0) {
      doc.fontSize(12).text('No equipment due for maintenance.');
    } else {
      report.dueEquipment.forEach(eq => {
        doc.fontSize(12).text(`• ${eq.name} - Last Maintenance: ${new Date(eq.last_maintenance_date).toLocaleDateString()}`);
      });
    }
    doc.moveDown();
    
    doc.fontSize(16).text('Overdue Borrowings:');
    if (report.overdueBorrowings.length === 0) {
      doc.fontSize(12).text('No overdue borrowings.');
    } else {
      report.overdueBorrowings.forEach(borrow => {
        doc.fontSize(12).text(`• Borrower: ${borrow.borrower_name} - Return Date: ${new Date(borrow.return_date).toLocaleDateString()}`);
      });
    }
    
    doc.end();
  } catch (error) {
    console.error('Error generating PDF report:', error);
    res.status(500).json({ error: 'Failed to generate PDF report' });
  }
});

// Export report as CSV
router.get('/csv', authenticateToken, requireAdminOrTechnician, async (req, res) => {
  try {
    const expiringChemicals = await Chemical.getExpiringSoon();
    const lowStockChemicals = await Chemical.getLowStock();
    const dueEquipment = await Equipment.getDueForMaintenance();
    const overdueBorrowings = await Borrowing.getOverdue();
    
    // Use the same logic as monthly report for consistent counts
    let pendingBorrowings = await Borrowing.count({ where: { status: 'pending', deleted_at: null } });
    
    // If no pending found, try other status values
    if (pendingBorrowings === 0) {
      const allBorrowings = await Borrowing.findAll({
        attributes: ['status'],
        where: { deleted_at: null },
        raw: true
      });
      
      const statusCounts = {};
      allBorrowings.forEach(borrowing => {
        const status = borrowing.status;
        statusCounts[status] = (statusCounts[status] || 0) + 1;
      });
      
      // Use same logic as monthly report
      if (statusCounts['submitted'] > 0) {
        pendingBorrowings = statusCounts['submitted'];
      } else if (statusCounts['requested'] > 0) {
        pendingBorrowings = statusCounts['requested'];
      } else if (statusCounts['awaiting_approval'] > 0) {
        pendingBorrowings = statusCounts['awaiting_approval'];
      }
    }
    
    const report = {
      summary: {
        totalChemicals: await Chemical.count({ where: { deleted_at: null } }),
        totalEquipment: await Equipment.count({ where: { deleted_at: null } }),
        activeBorrowings: await Borrowing.count({ where: { status: 'approved', deleted_at: null } }),
        pendingBorrowings: pendingBorrowings,
        overdueBorrowings: overdueBorrowings.length
      },
      expiringChemicals,
      lowStockChemicals,
      dueEquipment,
      overdueBorrowings
    };
    
    const filename = `chemlab-report-${new Date().toISOString().split('T')[0]}.csv`;
    
    res.setHeader('Content-disposition', `attachment; filename="${filename}"`);
    res.setHeader('Content-type', 'text/csv');
    
    // Create CSV content
    let csvContent = 'Category,Item,Details\n';
    
    // Add summary
    csvContent += `"Summary","Total Chemicals","${report.summary.totalChemicals}"\n`;
    csvContent += `"Summary","Total Equipment","${report.summary.totalEquipment}"\n`;
    csvContent += `"Summary","Active Borrowings","${report.summary.activeBorrowings}"\n`;
    csvContent += `"Summary","Pending Borrowings","${report.summary.pendingBorrowings}"\n`;
    csvContent += `"Summary","Overdue Borrowings","${report.summary.overdueBorrowings}"\n`;
    
    // Add expiring chemicals
    report.expiringChemicals.forEach(chem => {
      csvContent += `"Expiring Chemicals","${chem.name}","Expires: ${new Date(chem.expiry_date).toLocaleDateString()}"\n`;
    });
    
    // Add low stock chemicals
    report.lowStockChemicals.forEach(chem => {
      csvContent += `"Low Stock Chemicals","${chem.name}","Quantity: ${chem.quantity} ${chem.unit}"\n`;
    });
    
    // Add due equipment
    report.dueEquipment.forEach(eq => {
      csvContent += `"Due Equipment","${eq.name}","Last Maintenance: ${new Date(eq.last_maintenance_date).toLocaleDateString()}"\n`;
    });
    
    // Add overdue borrowings
    report.overdueBorrowings.forEach(borrow => {
      csvContent += `"Overdue Borrowings","${borrow.borrower_name}","Return Date: ${new Date(borrow.return_date).toLocaleDateString()}"\n`;
    });
    
    res.send(csvContent);
  } catch (error) {
    console.error('Error generating CSV report:', error);
    res.status(500).json({ error: 'Failed to generate CSV report' });
  }
});

module.exports = router;