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
    const expiringChemicals = await Chemical.getExpiringSoon();
    const lowStockChemicals = await Chemical.getLowStock();
    const dueEquipment = await Equipment.getDueForMaintenance();
    const overdueBorrowings = await Borrowing.getOverdue();
    
    const report = {
      summary: {
        totalChemicals: (await Chemical.findAll()).length,
        totalEquipment: (await Equipment.findAll()).length,
        activeBorrowings: (await Borrowing.findAll({ status: 'approved' })).length,
        pendingBorrowings: (await Borrowing.findAll({ status: 'pending' })).length,
        overdueBorrowings: overdueBorrowings.length
      },
      expiringChemicals,
      lowStockChemicals,
      dueEquipment,
      overdueBorrowings
    };
    
    res.json(report);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Export report as PDF
router.get('/pdf', authenticateToken, requireAdminOrTechnician, async (req, res) => {
  try {
    const expiringChemicals = await Chemical.getExpiringSoon();
    const lowStockChemicals = await Chemical.getLowStock();
    const dueEquipment = await Equipment.getDueForMaintenance();
    const overdueBorrowings = await Borrowing.getOverdue();
    
    const report = {
      summary: {
        totalChemicals: (await Chemical.findAll()).length,
        totalEquipment: (await Equipment.findAll()).length,
        activeBorrowings: (await Borrowing.findAll({ status: 'approved' })).length,
        pendingBorrowings: (await Borrowing.findAll({ status: 'pending' })).length,
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
    
    const report = {
      summary: {
        totalChemicals: (await Chemical.findAll()).length,
        totalEquipment: (await Equipment.findAll()).length,
        activeBorrowings: (await Borrowing.findAll({ status: 'approved' })).length,
        pendingBorrowings: (await Borrowing.findAll({ status: 'pending' })).length,
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