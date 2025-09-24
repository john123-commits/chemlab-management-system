const express = require('express');
const Chemical = require('../models/Chemical');
const Equipment = require('../models/Equipment');
const Borrowing = require('../models/Borrowing');
const PDFDocument = require('pdfkit');
const createCsvWriter = require('csv-writer').createObjectCsvWriter;
const { authenticateToken, requireAdminOrTechnician } = require('../middleware/auth');
const db = require('../config/db');
const router = express.Router();

// Helper function to draw pie slice
function drawPieSlice(doc, centerX, centerY, radius, startAngle, endAngle, fillColor) {
  if (endAngle - startAngle <= 0) return;
  
  const startX = centerX + radius * Math.cos(startAngle);
  const startY = centerY + radius * Math.sin(startAngle);
  const endX = centerX + radius * Math.cos(endAngle);
  const endY = centerY + radius * Math.sin(endAngle);
  
  const largeArcFlag = (endAngle - startAngle > Math.PI) ? 1 : 0;
  
  doc.moveTo(centerX, centerY)
     .lineTo(startX, startY);
  
  // For small angles, just draw lines. For larger angles, use arc
  if (endAngle - startAngle > 0.1) {
    doc.arc(centerX, centerY, radius, startAngle * 180 / Math.PI, endAngle * 180 / Math.PI, false);
  } else {
    doc.lineTo(endX, endY);
  }
  
  doc.lineTo(centerX, centerY)
     .fillColor(fillColor)
     .fill();
}

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
      totalChemicals = await Chemical.count({
        where: {
          deleted_at: null
        }
      });
      console.log('Total chemicals count:', totalChemicals);
    } catch (error) {
      console.warn('Could not get total chemicals count:', error.message);
      try {
        totalChemicals = (await Chemical.findAll({
          where: { deleted_at: null }
        })).length;
      } catch (fallbackError) {
        console.warn('Fallback chemical count also failed:', fallbackError.message);
      }
    }
    
    try {
      totalEquipment = await Equipment.count({
        where: {
          deleted_at: null
        }
      });
      console.log('Total equipment count:', totalEquipment);
    } catch (error) {
      console.warn('Could not get total equipment count:', error.message);
      try {
        totalEquipment = (await Equipment.findAll({
          where: { deleted_at: null }
        })).length;
      } catch (fallbackError) {
        console.warn('Fallback equipment count also failed:', fallbackError.message);
      }
    }
    
    try {
      activeBorrowings = await Borrowing.count({
        where: {
          status: 'approved',
          deleted_at: null
        }
      });
      console.log('Active borrowings count:', activeBorrowings);
    } catch (error) {
      console.warn('Could not get active borrowings count:', error.message);
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

/// Replace the PDF generation route with this improved version

// Export report as PDF
router.get('/pdf', authenticateToken, requireAdminOrTechnician, async (req, res) => {
  try {
    console.log('Starting PDF generation...');

    // Test database connection first
    try {
      await db.query('SELECT 1');
      console.log('Database connection successful');
    } catch (dbError) {
      console.error('Database connection failed:', dbError);
      throw new Error('Database connection failed: ' + dbError.message);
    }

    const expiringChemicals = await Chemical.getExpiringSoon();
    console.log('Found expiring chemicals:', expiringChemicals.length);

    const lowStockChemicals = await Chemical.getLowStock();
    console.log('Found low stock chemicals:', lowStockChemicals.length);

    const dueEquipment = await Equipment.getDueForMaintenance();
    console.log('Found due equipment:', dueEquipment.length);

    const overdueBorrowings = await Borrowing.getOverdue();
    console.log('Found overdue borrowings:', overdueBorrowings.length);

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

    const activeBorrowingsCount = await Borrowing.count({ where: { status: 'approved', deleted_at: null } });

    const report = {
      summary: {
        totalChemicals: await Chemical.count({ where: { deleted_at: null } }),
        totalEquipment: await Equipment.count({ where: { deleted_at: null } }),
        activeBorrowings: activeBorrowingsCount,
        pendingBorrowings: pendingBorrowings,
        overdueBorrowings: overdueBorrowings.length
      },
      expiringChemicals,
      lowStockChemicals,
      dueEquipment,
      overdueBorrowings
    };

    console.log('Report data prepared:', report.summary);

    const doc = new PDFDocument({ margin: 40 });
    const filename = `chemlab-report-${new Date().toISOString().split('T')[0]}.pdf`;

    res.setHeader('Content-disposition', `attachment; filename="${filename}"`);
    res.setHeader('Content-type', 'application/pdf');

    doc.pipe(res);

    // ========================================
    // HEADER SECTION
    // ========================================
    doc.fontSize(24)
       .fillColor('#2c3e50')
       .text('ChemLab Management System', 50, 50, { align: 'center' });
    
    doc.fontSize(18)
       .fillColor('#34495e')
       .text('Monthly Report', 50, 80, { align: 'center' });

    doc.fontSize(12)
       .fillColor('#7f8c8d')
       .text(`Generated: ${new Date().toLocaleString()}`, 50, 110, { align: 'center' });

    // Horizontal line
    doc.moveTo(50, 140)
       .lineTo(550, 140)
       .strokeColor('#bdc3c7')
       .lineWidth(2)
       .stroke();

    // ========================================
    // EXECUTIVE SUMMARY CARDS
    // ========================================
    doc.fontSize(16)
       .fillColor('#2c3e50')
       .text('Executive Summary', 50, 160);

    const cardStartY = 190;
    const cardWidth = 90;
    const cardHeight = 70;
    const cardSpacing = 105;

    // Helper function to create summary cards
    function createSummaryCard(x, y, title, value, color, icon) {
      // Card background
      doc.rect(x, y, cardWidth, cardHeight)
         .fillColor('#ffffff')
         .fill()
         .strokeColor(color)
         .lineWidth(2)
         .stroke();

      // Value (large number)
      doc.fontSize(20)
         .fillColor(color)
         .text(value.toString(), x + 10, y + 15, { width: cardWidth - 20, align: 'center' });

      // Title (smaller text)
      doc.fontSize(9)
         .fillColor('#2c3e50')
         .text(title, x + 5, y + 45, { width: cardWidth - 10, align: 'center' });
    }

    // Create summary cards
    createSummaryCard(50, cardStartY, 'Total Chemicals', report.summary.totalChemicals, '#27ae60');
    createSummaryCard(50 + cardSpacing, cardStartY, 'Total Equipment', report.summary.totalEquipment, '#3498db');
    createSummaryCard(50 + cardSpacing * 2, cardStartY, 'Active Borrowings', report.summary.activeBorrowings, '#27ae60');
    createSummaryCard(50 + cardSpacing * 3, cardStartY, 'Pending Borrowings', report.summary.pendingBorrowings, '#f39c12');
    createSummaryCard(50 + cardSpacing * 4, cardStartY, 'Overdue Items', report.summary.overdueBorrowings, '#e74c3c');

    // ========================================
    // DETAILED SECTIONS
    // ========================================
    let currentY = cardStartY + cardHeight + 40;

    // Helper function for section headers
    function addSectionHeader(title, y) {
      doc.fontSize(14)
         .fillColor('#2c3e50')
         .text(title, 50, y);
      return y + 25;
    }

    // Helper function for status items
    function addStatusItem(text, status, y) {
      const statusColors = {
        'good': '#27ae60',
        'warning': '#f39c12',
        'critical': '#e74c3c'
      };
      
      const statusIcons = {
        'good': '✓',
        'warning': '⚠',
        'critical': '✗'
      };

      doc.fontSize(10)
         .fillColor(statusColors[status])
         .text(statusIcons[status], 55, y);
      
      doc.fontSize(10)
         .fillColor('#2c3e50')
         .text(text, 75, y, { width: 470 });
      
      return y + 15;
    }

    // Expiring Chemicals Section
    currentY = addSectionHeader('Expiring Chemicals', currentY);
    if (report.expiringChemicals.length === 0) {
      currentY = addStatusItem('No expiring chemicals - All chemicals within safe expiry periods', 'good', currentY);
    } else {
      report.expiringChemicals.forEach(chem => {
        currentY = addStatusItem(`${chem.name} - Expires: ${new Date(chem.expiry_date).toLocaleDateString()}`, 'warning', currentY);
      });
    }
    currentY += 10;

    // Low Stock Chemicals Section
    currentY = addSectionHeader('Low Stock Chemicals', currentY);
    if (report.lowStockChemicals.length === 0) {
      currentY = addStatusItem('No low stock chemicals - All chemicals adequately stocked', 'good', currentY);
    } else {
      report.lowStockChemicals.forEach(chem => {
        currentY = addStatusItem(`${chem.name} - Quantity: ${chem.quantity} ${chem.unit}`, 'critical', currentY);
      });
    }
    currentY += 10;

    // Equipment Due for Maintenance Section
    currentY = addSectionHeader('Equipment Due for Maintenance', currentY);
    if (report.dueEquipment.length === 0) {
      currentY = addStatusItem('No equipment due for maintenance - All equipment up to date', 'good', currentY);
    } else {
      report.dueEquipment.forEach(eq => {
        currentY = addStatusItem(`${eq.name} - Last Maintenance: ${new Date(eq.last_maintenance_date).toLocaleDateString()}`, 'warning', currentY);
      });
    }
    currentY += 10;

    // Overdue Borrowings Section
    currentY = addSectionHeader('Overdue Borrowings', currentY);
    if (report.overdueBorrowings.length === 0) {
      currentY = addStatusItem('No overdue borrowings - All items returned on time', 'good', currentY);
    } else {
      report.overdueBorrowings.forEach(borrow => {
        currentY = addStatusItem(`${borrow.borrower_name} - Due: ${new Date(borrow.return_date).toLocaleDateString()}`, 'critical', currentY);
      });
    }

    // ========================================
    // NEW PAGE FOR CHARTS
    // ========================================
    doc.addPage({ margin: 40 });

    doc.fontSize(20)
       .fillColor('#2c3e50')
       .text('Data Visualizations & Analytics', 50, 50, { align: 'center' });

    // Horizontal line
    doc.moveTo(50, 80)
       .lineTo(550, 80)
       .strokeColor('#bdc3c7')
       .lineWidth(2)
       .stroke();

    // ========================================
    // 1. CHEMICAL INVENTORY PIE CHART
    // ========================================
    doc.fontSize(16)
       .fillColor('#2c3e50')
       .text('Chemical Inventory Status Distribution', 50, 110);

    const chartTotalChemicals = report.summary.totalChemicals;
    const chartExpiringCount = report.expiringChemicals.length;
    const chartLowStockCount = report.lowStockChemicals.length;
    const chartNormalCount = Math.max(0, chartTotalChemicals - chartExpiringCount - chartLowStockCount);

    if (chartTotalChemicals > 0) {
      const pieX = 150;
      const pieY = 180;
      const pieRadius = 60;

      // Calculate percentages and angles
      const normalPercentage = Math.round((chartNormalCount / chartTotalChemicals) * 100);
      const expiringPercentage = Math.round((chartExpiringCount / chartTotalChemicals) * 100);
      const lowStockPercentage = Math.round((chartLowStockCount / chartTotalChemicals) * 100);

      const normalAngle = (chartNormalCount / chartTotalChemicals) * 360;
      const expiringAngle = (chartExpiringCount / chartTotalChemicals) * 360;
      const lowStockAngle = (chartLowStockCount / chartTotalChemicals) * 360;

      let currentAngle = 0;

      // Helper function to draw pie slice using paths
      function drawPieSliceFixed(centerX, centerY, radius, startAngle, endAngle, color) {
        if (endAngle <= startAngle) return;
        
        const startRad = (startAngle * Math.PI) / 180;
        const endRad = (endAngle * Math.PI) / 180;
        
        const x1 = centerX + radius * Math.cos(startRad);
        const y1 = centerY + radius * Math.sin(startRad);
        const x2 = centerX + radius * Math.cos(endRad);
        const y2 = centerY + radius * Math.sin(endRad);
        
        const largeArcFlag = (endAngle - startAngle > 180) ? 1 : 0;
        
        doc.save();
        doc.path(`M ${centerX} ${centerY} L ${x1} ${y1} A ${radius} ${radius} 0 ${largeArcFlag} 1 ${x2} ${y2} Z`)
           .fillColor(color)
           .fill();
        doc.restore();
      }

      // Draw pie slices
      if (chartNormalCount > 0) {
        drawPieSliceFixed(pieX, pieY, pieRadius, currentAngle, currentAngle + normalAngle, '#27ae60');
        currentAngle += normalAngle;
      }
      
      if (chartExpiringCount > 0) {
        drawPieSliceFixed(pieX, pieY, pieRadius, currentAngle, currentAngle + expiringAngle, '#f39c12');
        currentAngle += expiringAngle;
      }
      
      if (chartLowStockCount > 0) {
        drawPieSliceFixed(pieX, pieY, pieRadius, currentAngle, currentAngle + lowStockAngle, '#e74c3c');
      }

      // Center circle for donut effect
      doc.circle(pieX, pieY, 20)
         .fillColor('#ffffff')
         .fill()
         .strokeColor('#2c3e50')
         .lineWidth(2)
         .stroke();

      // Center text
      doc.fontSize(14)
         .fillColor('#2c3e50')
         .text(chartTotalChemicals.toString(), pieX - 10, pieY - 7, { width: 20, align: 'center' });

      // Legend
      const legendX = 280;
      const legendY = 140;
      const legendSpacing = 20;

      if (chartNormalCount > 0) {
        doc.rect(legendX, legendY, 12, 12).fillColor('#27ae60').fill();
        doc.fontSize(10).fillColor('#2c3e50').text(`Normal: ${chartNormalCount} (${normalPercentage}%)`, legendX + 20, legendY + 2);
      }
      
      if (chartExpiringCount > 0) {
        doc.rect(legendX, legendY + legendSpacing, 12, 12).fillColor('#f39c12').fill();
        doc.fontSize(10).fillColor('#2c3e50').text(`Expiring: ${chartExpiringCount} (${expiringPercentage}%)`, legendX + 20, legendY + legendSpacing + 2);
      }
      
      if (chartLowStockCount > 0) {
        doc.rect(legendX, legendY + legendSpacing * 2, 12, 12).fillColor('#e74c3c').fill();
        doc.fontSize(10).fillColor('#2c3e50').text(`Low Stock: ${chartLowStockCount} (${lowStockPercentage}%)`, legendX + 20, legendY + legendSpacing * 2 + 2);
      }
    } else {
      doc.fontSize(12)
         .fillColor('#7f8c8d')
         .text('No chemical data available', 50, 150);
    }

    // ========================================
    // 2. EQUIPMENT STATUS BAR CHART
    // ========================================
    doc.fontSize(16)
       .fillColor('#2c3e50')
       .text('Equipment Status Overview', 50, 280);

    const chartTotalEquipment = report.summary.totalEquipment;
    const chartDueEquipment = report.dueEquipment.length;
    const chartGoodEquipment = chartTotalEquipment - chartDueEquipment;

    if (chartTotalEquipment > 0) {
      const barChartX = 80;
      const barChartY = 320;
      const barChartWidth = 400;
      const barChartHeight = 150;
      const barWidth = 50;
      
      // Chart background
      doc.rect(barChartX, barChartY, barChartWidth, barChartHeight)
         .strokeColor('#e5e5e5')
         .lineWidth(1)
         .stroke();

      // Y-axis
      doc.moveTo(barChartX, barChartY)
         .lineTo(barChartX, barChartY + barChartHeight)
         .strokeColor('#2c3e50')
         .lineWidth(2)
         .stroke();

      // X-axis
      doc.moveTo(barChartX, barChartY + barChartHeight)
         .lineTo(barChartX + barChartWidth, barChartY + barChartHeight)
         .strokeColor('#2c3e50')
         .lineWidth(2)
         .stroke();

      // Calculate bar heights
      const maxValue = Math.max(chartGoodEquipment, chartDueEquipment, 1);
      const scale = (barChartHeight - 20) / maxValue;

      // Good equipment bar
      const goodBarHeight = chartGoodEquipment * scale;
      const goodBarX = barChartX + 100;
      const goodBarY = barChartY + barChartHeight - 10 - goodBarHeight;

      doc.rect(goodBarX, goodBarY, barWidth, goodBarHeight)
         .fillColor('#27ae60')
         .fill();

      // Due equipment bar
      const dueBarHeight = chartDueEquipment * scale;
      const dueBarX = barChartX + 250;
      const dueBarY = barChartY + barChartHeight - 10 - dueBarHeight;

      doc.rect(dueBarX, dueBarY, barWidth, dueBarHeight)
         .fillColor('#f39c12')
         .fill();

      // Bar labels
      doc.fontSize(10)
         .fillColor('#2c3e50')
         .text(chartGoodEquipment.toString(), goodBarX + 20, goodBarY - 15, { width: 20, align: 'center' });
      doc.text(chartDueEquipment.toString(), dueBarX + 20, dueBarY - 15, { width: 20, align: 'center' });

      // Category labels
      doc.fontSize(9)
         .text('Good', goodBarX + 15, barChartY + barChartHeight + 5, { width: 30, align: 'center' });
      doc.text('Needs', dueBarX + 10, barChartY + barChartHeight + 5, { width: 40, align: 'center' });
      doc.text('Maintenance', dueBarX, barChartY + barChartHeight + 15, { width: 60, align: 'center' });

      // Y-axis labels
      for (let i = 0; i <= maxValue; i += Math.max(1, Math.ceil(maxValue / 4))) {
        const yPos = barChartY + barChartHeight - 10 - (i * scale);
        doc.fontSize(8)
           .fillColor('#666666')
           .text(i.toString(), barChartX - 15, yPos - 3);
      }
    } else {
      doc.fontSize(12)
         .fillColor('#7f8c8d')
         .text('No equipment data available', 50, 320);
    }

    // ========================================
    // 3. BORROWING STATISTICS (MOVED UP)
    // ========================================
    doc.fontSize(16)
       .fillColor('#2c3e50')
       .text('Borrowing Statistics', 50, 490);

    const totalBorrowings = report.summary.activeBorrowings + report.summary.pendingBorrowings + report.summary.overdueBorrowings;

    if (totalBorrowings > 0) {
      const borrowingBarY = 515;
      const borrowingBarWidth = 300;
      const borrowingBarHeight = 25;
      
      // Calculate segments
      const activeWidth = (report.summary.activeBorrowings / totalBorrowings) * borrowingBarWidth;
      const pendingWidth = (report.summary.pendingBorrowings / totalBorrowings) * borrowingBarWidth;
      const overdueWidth = (report.summary.overdueBorrowings / totalBorrowings) * borrowingBarWidth;

      let currentX = 80;

      // Active segment
      if (report.summary.activeBorrowings > 0) {
        doc.rect(currentX, borrowingBarY, activeWidth, borrowingBarHeight)
           .fillColor('#27ae60')
           .fill();
        currentX += activeWidth;
      }

      // Pending segment
      if (report.summary.pendingBorrowings > 0) {
        doc.rect(currentX, borrowingBarY, pendingWidth, borrowingBarHeight)
           .fillColor('#f39c12')
           .fill();
        currentX += pendingWidth;
      }

      // Overdue segment
      if (report.summary.overdueBorrowings > 0) {
        doc.rect(currentX, borrowingBarY, overdueWidth, borrowingBarHeight)
           .fillColor('#e74c3c')
           .fill();
      }

      // Border
      doc.rect(80, borrowingBarY, borrowingBarWidth, borrowingBarHeight)
         .strokeColor('#2c3e50')
         .lineWidth(1)
         .stroke();

      // Legend (more compact)
      const legendY = borrowingBarY + 35;
      doc.rect(80, legendY, 8, 8).fillColor('#27ae60').fill();
      doc.fontSize(8).fillColor('#2c3e50').text(`Active: ${report.summary.activeBorrowings}`, 92, legendY + 1);
      
      doc.rect(150, legendY, 8, 8).fillColor('#f39c12').fill();
      doc.fontSize(8).text(`Pending: ${report.summary.pendingBorrowings}`, 162, legendY + 1);
      
      doc.rect(220, legendY, 8, 8).fillColor('#e74c3c').fill();
      doc.fontSize(8).text(`Overdue: ${report.summary.overdueBorrowings}`, 232, legendY + 1);
    } else {
      doc.fontSize(12)
         .fillColor('#7f8c8d')
         .text('No borrowing data available', 50, 515);
    }

    // ========================================
    // RECOMMENDATIONS (MOVED UP)
    // ========================================
    doc.fontSize(16)
       .fillColor('#2c3e50')
       .text('Key Recommendations', 50, 580);

    let recY = 605;
    let hasRecommendations = false;

    if (report.lowStockChemicals.length > 0) {
      doc.fontSize(10)
         .fillColor('#e74c3c')
         .text('•', 55, recY);
      doc.fillColor('#2c3e50')
         .text(`Restock ${report.lowStockChemicals.length} chemical(s) immediately`, 70, recY);
      recY += 15;
      hasRecommendations = true;
    }

    if (report.expiringChemicals.length > 0) {
      doc.fontSize(10)
         .fillColor('#f39c12')
         .text('•', 55, recY);
      doc.fillColor('#2c3e50')
         .text(`Review ${report.expiringChemicals.length} expiring chemical(s)`, 70, recY);
      recY += 15;
      hasRecommendations = true;
    }

    if (report.dueEquipment.length > 0) {
      doc.fontSize(10)
         .fillColor('#f39c12')
         .text('•', 55, recY);
      doc.fillColor('#2c3e50')
         .text(`Schedule maintenance for ${report.dueEquipment.length} equipment item(s)`, 70, recY);
      recY += 15;
      hasRecommendations = true;
    }

    if (report.overdueBorrowings.length > 0) {
      doc.fontSize(10)
         .fillColor('#e74c3c')
         .text('•', 55, recY);
      doc.fillColor('#2c3e50')
         .text(`Follow up on ${report.overdueBorrowings.length} overdue item(s)`, 70, recY);
      recY += 15;
      hasRecommendations = true;
    }

    if (!hasRecommendations) {
      doc.fontSize(10)
         .fillColor('#27ae60')
         .text('•', 55, recY);
      doc.fillColor('#2c3e50')
         .text('All systems operating normally', 70, recY);
    }

    // Add footer function for automatic page numbering
    function addFooter() {
      const pageNumber = doc._pageBuffer.length;
      doc.fontSize(8)
         .fillColor('#7f8c8d')
         .text(`ChemLab Management System | Generated ${new Date().toLocaleDateString()} | Page ${pageNumber}`, 50, 750, { 
           align: 'center',
           width: 500
         });
    }

    // Add footer to current page
    addFooter();

    doc.end();
    console.log('PDF generation completed successfully');
  } catch (error) {
    console.error('Error generating PDF report:', error);
    console.error('Error stack:', error.stack);
    res.status(500).json({
      error: 'Failed to generate PDF report',
      details: error.message,
      stack: error.stack
    });
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
    console.log('Pending borrowings count:', pendingBorrowings);

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

      console.log('All borrowing statuses:', statusCounts);

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
    
    // Create enhanced CSV content with analytics
    let csvContent = 'Category,Item,Details,Status,Priority\n';
    
    // Add summary with status indicators
    csvContent += `"Executive Summary","Total Chemicals","${report.summary.totalChemicals}","Active","Info"\n`;
    csvContent += `"Executive Summary","Total Equipment","${report.summary.totalEquipment}","Active","Info"\n`;
    csvContent += `"Executive Summary","Active Borrowings","${report.summary.activeBorrowings}","Good","Low"\n`;
    csvContent += `"Executive Summary","Pending Borrowings","${report.summary.pendingBorrowings}","Warning","Medium"\n`;
    csvContent += `"Executive Summary","Overdue Borrowings","${report.summary.overdueBorrowings}","Critical","High"\n`;
    
    // Add expiring chemicals with priority
    if (report.expiringChemicals.length === 0) {
      csvContent += `"Expiring Chemicals","None","All chemicals within safe expiry periods","Good","Low"\n`;
    } else {
      report.expiringChemicals.forEach(chem => {
        const daysUntilExpiry = Math.ceil((new Date(chem.expiry_date) - new Date()) / (1000 * 60 * 60 * 24));
        const priority = daysUntilExpiry <= 30 ? 'High' : daysUntilExpiry <= 60 ? 'Medium' : 'Low';
        csvContent += `"Expiring Chemicals","${chem.name}","Expires: ${new Date(chem.expiry_date).toLocaleDateString()}","Warning","${priority}"\n`;
      });
    }
    
    // Add low stock chemicals
    if (report.lowStockChemicals.length === 0) {
      csvContent += `"Low Stock Chemicals","None","All chemicals adequately stocked","Good","Low"\n`;
    } else {
      report.lowStockChemicals.forEach(chem => {
        csvContent += `"Low Stock Chemicals","${chem.name}","Quantity: ${chem.quantity} ${chem.unit}","Critical","High"\n`;
      });
    }
    
    // Add due equipment
    if (report.dueEquipment.length === 0) {
      csvContent += `"Equipment Maintenance","None","All equipment up to date","Good","Low"\n`;
    } else {
      report.dueEquipment.forEach(eq => {
        csvContent += `"Equipment Maintenance","${eq.name}","Last Maintenance: ${new Date(eq.last_maintenance_date).toLocaleDateString()}","Warning","Medium"\n`;
      });
    }
    
    // Add overdue borrowings
    if (report.overdueBorrowings.length === 0) {
      csvContent += `"Overdue Borrowings","None","All items returned on time","Good","Low"\n`;
    } else {
      report.overdueBorrowings.forEach(borrow => {
        const daysOverdue = Math.ceil((new Date() - new Date(borrow.return_date)) / (1000 * 60 * 60 * 24));
        const priority = daysOverdue > 7 ? 'High' : 'Medium';
        csvContent += `"Overdue Borrowings","${borrow.borrower_name}","Return Date: ${new Date(borrow.return_date).toLocaleDateString()} (${daysOverdue} days overdue)","Critical","${priority}"\n`;
      });
    }
    
    // Add analytics summary
    const totalChemicals = report.summary.totalChemicals;
    const normalChemicals = totalChemicals - report.expiringChemicals.length - report.lowStockChemicals.length;
    const chemicalHealthScore = totalChemicals > 0 ? Math.round((normalChemicals / totalChemicals) * 100) : 0;
    
    csvContent += `"Analytics","Chemical Health Score","${chemicalHealthScore}%","${chemicalHealthScore >= 80 ? 'Good' : chemicalHealthScore >= 60 ? 'Warning' : 'Critical'}","${chemicalHealthScore >= 80 ? 'Low' : chemicalHealthScore >= 60 ? 'Medium' : 'High'}"\n`;
    
    const equipmentHealthScore = report.summary.totalEquipment > 0 ? Math.round(((report.summary.totalEquipment - report.dueEquipment.length) / report.summary.totalEquipment) * 100) : 100;
    csvContent += `"Analytics","Equipment Health Score","${equipmentHealthScore}%","${equipmentHealthScore >= 80 ? 'Good' : equipmentHealthScore >= 60 ? 'Warning' : 'Critical'}","${equipmentHealthScore >= 80 ? 'Low' : equipmentHealthScore >= 60 ? 'Medium' : 'High'}"\n`;
    
    res.send(csvContent);
    console.log('Enhanced CSV report generated successfully');
  } catch (error) {
    console.error('Error generating CSV report:', error);
    res.status(500).json({ error: 'Failed to generate CSV report: ' + error.message });
  }
});

module.exports = router;