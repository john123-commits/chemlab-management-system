const PDFDocument = require('pdfkit');
const Chemical = require('../models/Chemical');
const fs = require('fs');
const path = require('path');

const generateChemicalsPDF = async (req, res) => {
  try {
    const {
      // Filter options
      category = 'All',
      lowStockOnly = false,
      expiringSoon = 0,
      search = '',

      // Content sections
      includeBasicInfo = true,
      includePhysicalProperties = true,
      includeStorageSafety = true,
      includeStockAnalysis = false,
      includeDocuments = false,

      // Additional options
      includeStatistics = true,
      showQRCodes = false
    } = req.body;

    // Get filtered chemicals
    const chemicals = await Chemical.getFilteredChemicals({
      category,
      lowStockOnly,
      expiringSoon,
      search
    });

    // Get stock analysis if requested
    let stockAnalysis = null;
    if (includeStockAnalysis || includeStatistics) {
      stockAnalysis = await Chemical.getStockAnalysis();
    }

    // Create PDF document
    const doc = new PDFDocument({ margin: 50 });

    // Set response headers
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', 'attachment; filename=chemical-inventory.pdf');

    // Pipe the PDF to response
    doc.pipe(res);

    // Generate PDF content
    await generatePDFContent(doc, chemicals, stockAnalysis, {
      includeBasicInfo,
      includePhysicalProperties,
      includeStorageSafety,
      includeStockAnalysis,
      includeDocuments,
      includeStatistics,
      showQRCodes,
      filters: { category, lowStockOnly, expiringSoon, search }
    });

    doc.end();

  } catch (error) {
    console.error('PDF Generation Error:', error);
    res.status(500).json({ error: error.message });
  }
};

async function generatePDFContent(doc, chemicals, stockAnalysis, options) {
  // Professional Header
  doc.fontSize(10).fillColor('#7f8c8d');
  doc.text('Chemistry Laboratory Management System', { align: 'center' });
  doc.text('Chemical Inventory & Safety Report', { align: 'center' });
  doc.moveDown(0.5);

  doc.fontSize(24).fillColor('#2c3e50').text('CHEMICAL INVENTORY REPORT', { align: 'center' });
  doc.fontSize(10).fillColor('#7f8c8d').text(`Generated on: ${new Date().toLocaleDateString()} at ${new Date().toLocaleTimeString()}`, { align: 'center' });
  
  // Add horizontal line
  doc.moveTo(50, doc.y + 10).lineTo(doc.page.width - 50, doc.y + 10).stroke('#bdc3c7');
  doc.moveDown(2);

  // Enhanced Statistics Section - Fixed Layout
  if (options.includeStatistics && stockAnalysis) {
    const statsBoxTop = doc.y;
    doc.rect(50, statsBoxTop, doc.page.width - 100, 140).fill('#ecf0f1');
    
    doc.fontSize(16).fillColor('#2c3e50').text('INVENTORY SUMMARY', 70, statsBoxTop + 15);
    
    // Single column layout for better readability
    const leftMargin = 70;
    let currentStatsY = statsBoxTop + 45;
    const lineHeight = 18;
    
    doc.fontSize(12).fillColor('#34495e');
    
    // Display stats in a single column with proper spacing
    doc.text(`Total Chemicals:`, leftMargin, currentStatsY);
    doc.fillColor('#27ae60').text(`${stockAnalysis.total_chemicals}`, leftMargin + 200, currentStatsY);
    currentStatsY += lineHeight;
    
    doc.fillColor('#34495e').text(`Low Stock Items:`, leftMargin, currentStatsY);
    doc.fillColor('#e74c3c').text(`${stockAnalysis.low_stock_count}`, leftMargin + 200, currentStatsY);
    currentStatsY += lineHeight;
    
    doc.fillColor('#34495e').text(`Expiring Soon (30 days):`, leftMargin, currentStatsY);
    doc.fillColor('#f39c12').text(`${stockAnalysis.expiring_soon_count}`, leftMargin + 200, currentStatsY);
    currentStatsY += lineHeight;
    
    doc.fillColor('#34495e').text(`Expired Items:`, leftMargin, currentStatsY);
    doc.fillColor('#c0392b').text(`${stockAnalysis.expired_count}`, leftMargin + 200, currentStatsY);
    currentStatsY += lineHeight;
    
    // Total value (removed currency symbol)
    if (stockAnalysis.total_inventory_value && parseFloat(stockAnalysis.total_inventory_value) > 0) {
      doc.fillColor('#34495e').text(`Total Inventory Value:`, leftMargin, currentStatsY);
      doc.text(`${parseFloat(stockAnalysis.total_inventory_value).toFixed(2)}`, leftMargin + 200, currentStatsY);
    }
    
    doc.y = statsBoxTop + 150;
    doc.moveDown(1);
  }

  // Add color legend if needed
  if (chemicals.some(c => c.is_low_stock || c.is_expiring_soon)) {
    doc.fontSize(10).fillColor('#2c3e50').text('Legend:', 70, doc.y);
    doc.moveDown(0.3);
    
    // Low stock indicator
    doc.rect(70, doc.y, 10, 10).fill('#e74c3c');
    doc.fillColor('#2c3e50').text('Low Stock Items', 90, doc.y + 2);
    
    // Expiring soon indicator  
    doc.rect(200, doc.y, 10, 10).fill('#f39c12');
    doc.text('Expiring Soon', 220, doc.y + 2);
    
    doc.moveDown(1);
  }

  // Enhanced Table Section with Dynamic Column Widths
  doc.fontSize(16).fillColor('#2c3e50').text('CHEMICAL DETAILS');
  doc.moveDown(0.5);

  const columns = getColumns(options);
  const tableStartY = doc.y;
  const rowHeight = 30; // Increased from 25 to 30
  const tableWidth = doc.page.width - 100;

  // Define optimal column widths based on content
  const getColumnWidths = (columns) => {
    const widthMap = {
      'Chemical Name': 90,
      'Category': 60,
      'Quantity': 60,
      'Location': 70,
      'Initial Qty': 55,
      'Used': 40,
      'Reorder Level': 60,
      'CAS Number': 65,
      'Formula': 55,
      'State': 45,
      'Hazard Class': 75,
      'Expiry Date': 65
    };
    
    return columns.map(col => widthMap[col.header] || 60);
  };

  const colWidths = getColumnWidths(columns);
  const totalCalculatedWidth = colWidths.reduce((sum, width) => sum + width, 0);
  
  // Scale widths to fit available space
  const scaleFactor = tableWidth / totalCalculatedWidth;
  const scaledWidths = colWidths.map(width => width * scaleFactor);

  // Table header with background
  doc.rect(50, tableStartY, tableWidth, rowHeight).fill('#3498db');
  
  // Header text with proper positioning
  doc.fontSize(9).fillColor('white'); // Reduced font size from 10 to 9
  let currentX = 50;
  columns.forEach((col, index) => {
    doc.text(col.header, currentX + 5, tableStartY + 10, { 
      width: scaledWidths[index] - 10, 
      align: 'left',
      lineBreak: false,
      ellipsis: true
    });
    currentX += scaledWidths[index];
  });

  let currentY = tableStartY + rowHeight;

  // Table rows with alternating colors
  chemicals.forEach((chemical, index) => {
    // Check for new page
    if (currentY > doc.page.height - 100) {
      doc.addPage();
      currentY = 50;
      
      // Redraw header on new page
      doc.rect(50, currentY, tableWidth, rowHeight).fill('#3498db');
      doc.fontSize(9).fillColor('white');
      let headerX = 50;
      columns.forEach((col, colIndex) => {
        doc.text(col.header, headerX + 5, currentY + 10, { 
          width: scaledWidths[colIndex] - 10, 
          align: 'left',
          lineBreak: false,
          ellipsis: true
        });
        headerX += scaledWidths[colIndex];
      });
      currentY += rowHeight;
    }

    // Alternating row colors
    const rowColor = index % 2 === 0 ? '#ffffff' : '#f8f9fa';
    doc.rect(50, currentY, tableWidth, rowHeight).fill(rowColor);

    // Set text color based on status
    let textColor = '#2c3e50';
    if (chemical.is_low_stock) {
      textColor = '#e74c3c';
    } else if (chemical.is_expiring_soon) {
      textColor = '#f39c12';
    }

    doc.fontSize(8).fillColor(textColor); // Reduced font size from 9 to 8

    // Draw cell content with proper positioning
    let cellX = 50;
    columns.forEach((col, colIndex) => {
      const value = getColumnValue(chemical, col.key);
      doc.text(value, cellX + 5, currentY + 10, {
        width: scaledWidths[colIndex] - 10,
        height: rowHeight - 6,
        ellipsis: true,
        align: 'left',
        lineBreak: false
      });
      cellX += scaledWidths[colIndex];
    });

    currentY += rowHeight;
  });

  // Professional Footer
  doc.fontSize(8).fillColor('#7f8c8d');
  const footerY = doc.page.height - 30;
  doc.text(`Chemical Laboratory Management System | Report contains ${chemicals.length} chemicals | Generated: ${new Date().toLocaleString()}`, 
    50, footerY, { width: doc.page.width - 100, align: 'center' });
}

function getColumns(options) {
  const columns = [];

  if (options.includeBasicInfo) {
    columns.push(
      { key: 'name', header: 'Chemical Name' },
      { key: 'category', header: 'Category' },
      { key: 'quantity_unit', header: 'Quantity' },
      { key: 'storage_location', header: 'Location' }
    );
  }

  if (options.includeStockAnalysis) {
    columns.push(
      { key: 'initial_quantity', header: 'Initial Qty' },
      { key: 'quantity_used', header: 'Used' },
      { key: 'reorder_level', header: 'Reorder Level' }
    );
  }

  if (options.includePhysicalProperties) {
    columns.push(
      { key: 'c_number', header: 'CAS Number' },
      { key: 'molecular_formula', header: 'Formula' },
      { key: 'physical_state', header: 'State' }
    );
  }

  if (options.includeStorageSafety) {
    columns.push(
      { key: 'hazard_class', header: 'Hazard Class' },
      { key: 'expiry_date', header: 'Expiry Date' }
    );
  }

  return columns;
}

function getColumnValue(chemical, key) {
  switch(key) {
    case 'quantity_unit':
      return `${chemical.quantity} ${chemical.unit}`;
    case 'expiry_date':
      return new Date(chemical.expiry_date).toLocaleDateString();
    case 'quantity_used':
      return chemical.quantity_used || '0';
    case 'initial_quantity':
      return chemical.initial_quantity ? `${chemical.initial_quantity}` : 'N/A';
    case 'reorder_level':
      return chemical.reorder_level ? `${chemical.reorder_level}` : 'N/A';
    default:
      return chemical[key] || '';
  }
}

module.exports = { generateChemicalsPDF };