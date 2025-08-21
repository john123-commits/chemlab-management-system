const express = require('express');
const Chemical = require('../models/Chemical');
const Equipment = require('../models/Equipment');
const Borrowing = require('../models/Borrowing');
const PDFDocument = require('pdfkit');

const createCsvWriter = require('csv-writer').createObjectCsvWriter;
const { authenticateToken } = require('../middleware/auth');
const router = express.Router();


// Middleware to check admin/technician role
const requireAdminOrTechnician = (req, res, next) => {
  if (req.user.role !== 'admin' && req.user.role !== 'technician') {
    return res.status(403).json({ error: 'Admin or technician access required' });
  }
  next();
};

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
    const report = await generateReportData();
    
    const doc = new PDFDocument();
    const filename = `chemlab-report-${new Date().toISOString().split('T')[0]}.pdf`;
    
    res.setHeader('Content-disposition', `attachment; filename=${filename}`);
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
    report.expiringChemicals.forEach(chem => {
      doc.fontSize(12).text(`• ${chem.name} - Expires: ${new Date(chem.expiry_date).toLocaleDateString()}`);
    });
    doc.moveDown();
    
    doc.fontSize(16).text('Low Stock Chemicals:');
    report.lowStockChemicals.forEach(chem => {
      doc.fontSize(12).text(`• ${chem.name} - Quantity: ${chem.quantity} ${chem.unit}`);
    });
    doc.moveDown();
    
    doc.fontSize(16).text('Equipment Due for Maintenance:');
    report.dueEquipment.forEach(eq => {
      doc.fontSize(12).text(`• ${eq.name} - Last Maintenance: ${new Date(eq.last_maintenance_date).toLocaleDateString()}`);
    });
    doc.moveDown();
    
    doc.fontSize(16).text('Overdue Borrowings:');
    report.overdueBorrowings.forEach(borrow => {
      doc.fontSize(12).text(`• Borrower: ${borrow.borrower_name} - Return Date: ${new Date(borrow.return_date).toLocaleDateString()}`);
    });
    
    doc.end();
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Export report as CSV
router.get('/csv', authenticateToken, requireAdminOrTechnician, async (req, res) => {
  try {
    const report = await generateReportData();
    const filename = `chemlab-report-${new Date().toISOString().split('T')[0]}.csv`;
    
    res.setHeader('Content-disposition', `attachment; filename=${filename}`);
    res.setHeader('Content-type', 'text/csv');
    
    const csvWriter = createCsvWriter({
      path: '',
      header: [
        { id: 'category', title: 'Category' },
        { id: 'item', title: 'Item' },
        { id: 'details', title: 'Details' }
      ]
    });
    
    const records = [
      { category: 'Summary', item: 'Total Chemicals', details: report.summary.totalChemicals },
      { category: 'Summary', item: 'Total Equipment', details: report.summary.totalEquipment },
      { category: 'Summary', item: 'Active Borrowings', details: report.summary.activeBorrowings },
      { category: 'Summary', item: 'Pending Borrowings', details: report.summary.pendingBorrowings },
      { category: 'Summary', item: 'Overdue Borrowings', details: report.summary.overdueBorrowings }
    ];
    
    // Add expiring chemicals
    report.expiringChemicals.forEach(chem => {
      records.push({
        category: 'Expiring Chemicals',
        item: chem.name,
        details: `Expires: ${new Date(chem.expiry_date).toLocaleDateString()}`
      });
    });
    
    // Add low stock chemicals
    report.lowStockChemicals.forEach(chem => {
      records.push({
        category: 'Low Stock Chemicals',
        item: chem.name,
        details: `Quantity: ${chem.quantity} ${chem.unit}`
      });
    });
    
    // Add due equipment
    report.dueEquipment.forEach(eq => {
      records.push({
        category: 'Due Equipment',
        item: eq.name,
        details: `Last Maintenance: ${new Date(eq.last_maintenance_date).toLocaleDateString()}`
      });
    });
    
    // Add overdue borrowings
    report.overdueBorrowings.forEach(borrow => {
      records.push({
        category: 'Overdue Borrowings',
        item: borrow.borrower_name,
        details: `Return Date: ${new Date(borrow.return_date).toLocaleDateString()}`
      });
    });
    
    await csvWriter.writeRecords(records);
    res.send(records.map(r => `${r.category},${r.item},${r.details}`).join('\n'));
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

async function generateReportData() {
  const expiringChemicals = await Chemical.getExpiringSoon();
  const lowStockChemicals = await Chemical.getLowStock();
  const dueEquipment = await Equipment.getDueForMaintenance();
  const overdueBorrowings = await Borrowing.getOverdue();
  
  return {
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
}

module.exports = router;