//
//  RootViewController.swift
//  SimpleEKDemo
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/6/30.
//
//
/*
     File: RootViewController.h
     File: RootViewController.m
 Abstract: Table view controller that displays events occuring within the next 24 hours. Prompts a user
 for access to their Calendar, then updates its UI according to their response.

  Version: 1.1

 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.

 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.

 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.

 Copyright (C) 2013 Apple Inc. All Rights Reserved.

 */

import UIKit
import EventKit
import EventKitUI

@objc(RootViewController)
class RootViewController: UITableViewController, EKEventEditViewDelegate {
    // EKEventStore instance associated with the current Calendar application
    var eventStore: EKEventStore!
    
    // Default calendar associated with the above event store
    var defaultCalendar: EKCalendar!
    
    // Array of all events happening within the next 24 hours
    var eventsList: [EKEvent] = []
    
    // Used to add events to Calendar
    @IBOutlet weak var addButton: UIBarButtonItem!
    
    
    //MARK: -
    //MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Initialize the event store
        self.eventStore = EKEventStore()
        // Initialize the events list
        // The Add button is initially disabled
        self.addButton.enabled = false
    }
    
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        // Check whether we are authorized to access Calendar
        self.checkEventStoreAccessForCalendar()
    }
    
    
    // This method is called when the user selects an event in the table view. It configures the destination
    // event view controller with this event.
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showEventViewController" {
            // Configure the destination event view controller
            let eventViewController = segue.destinationViewController as! EKEventViewController
            // Fetch the index path associated with the selected event
            let indexPath = self.tableView.indexPathForSelectedRow!
            // Set the view controller to display the selected event
            eventViewController.event = self.eventsList[indexPath.row]
            
            // Allow event editing
            eventViewController.allowsEditing = true
        }
    }
    
    
    //MARK: -
    //MARK: Table View
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.eventsList.count
    }
    
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("eventCell", forIndexPath: indexPath)
        
        // Get the event at the row selected and display its title
        cell.textLabel!.text = self.eventsList[indexPath.row].title
        return cell
    }
    
    
    //MARK: -
    //MARK: Access Calendar
    
    // Check the authorization status of our application for Calendar
    private func checkEventStoreAccessForCalendar() {
        let status = EKEventStore.authorizationStatusForEntityType(EKEntityType.Event)
        
        switch status {
            // Update our UI if the user has granted access to their Calendar
        case .Authorized: self.accessGrantedForCalendar()
            // Prompt the user for access to Calendar if there is no definitive answer
        case .NotDetermined: self.requestCalendarAccess()
            // Display a message if the user has denied or restricted access to Calendar
        case .Denied, .Restricted:
            if #available(iOS 8.0, *) {
                let alertController = UIAlertController(title: "Privacy Warning", message: "Permission was not granted for Calendar", preferredStyle: .Alert)
                let action = UIAlertAction(title: "OK", style: .Cancel, handler: nil)
                alertController.addAction(action)
                self.presentViewController(alertController, animated: true, completion: nil)
            } else {
                let alert = UIAlertView(title: "Privacy Warning", message: "Permission was not granted for Calendar",
                    delegate: nil,
                    cancelButtonTitle: "OK")
                alert.show()
            }
        }
    }
    
    
    // Prompt the user for access to their Calendar
    private func requestCalendarAccess() {
        self.eventStore.requestAccessToEntityType(.Event) {[weak self] granted, error in
            if granted {
                // Let's ensure that our code will be executed from the main queue
                dispatch_async(dispatch_get_main_queue()) {
                    // The user has granted access to their Calendar; let's populate our UI with all events occuring in the next 24 hours.
                    self?.accessGrantedForCalendar()
                }
            }
        }
    }
    
    
    // This method is called when the user has granted permission to Calendar
    private func accessGrantedForCalendar() {
        // Let's get the default calendar associated with our event store
        self.defaultCalendar = self.eventStore.defaultCalendarForNewEvents
        // Enable the Add button
        self.addButton.enabled = true
        // Fetch all events happening in the next 24 hours and put them into eventsList
        self.eventsList = self.fetchEvents()
        // Update the UI with the above events
        self.tableView.reloadData()
    }
    
    
    //MARK: -
    //MARK: Fetch events
    
    // Fetch all events happening in the next 24 hours
    private func fetchEvents() -> [EKEvent] {
        let startDate = NSDate()
        
        //Create the end date components
        let tomorrowDateComponents = NSDateComponents()
        tomorrowDateComponents.day = 1
        
        let endDate = NSCalendar.currentCalendar().dateByAddingComponents(tomorrowDateComponents,
            toDate: startDate,
            options: [])!
        // We will only search the default calendar for our events
        let calendarArray: [EKCalendar] = [self.defaultCalendar]
        
        // Create the predicate
        let predicate = self.eventStore.predicateForEventsWithStartDate(startDate,
            endDate: endDate,
            calendars: calendarArray)
        
        // Fetch all events that match the predicate
        let events = self.eventStore.eventsMatchingPredicate(predicate)
        
        return events
    }
    
    
    //MARK: -
    //MARK: Add a new event
    
    // Display an event edit view controller when the user taps the "+" button.
    // A new event is added to Calendar when the user taps the "Done" button in the above view controller.
    @IBAction func addEvent(_: AnyObject) {
        // Create an instance of EKEventEditViewController
        let addController = EKEventEditViewController()
        
        // Set addController's event store to the current event store
        addController.eventStore = self.eventStore!
        addController.editViewDelegate = self
        self.presentViewController(addController, animated: true, completion: nil)
    }
    
    
    //MARK: -
    //MARK: EKEventEditViewDelegate
    
    // Overriding EKEventEditViewDelegate method to update event store according to user actions.
    func eventEditViewController(controller: EKEventEditViewController, didCompleteWithAction action: EKEventEditViewAction) {
        // Dismiss the modal view controller
        self.dismissViewControllerAnimated(true) {[weak self] in
            if action != .Canceled {
                dispatch_async(dispatch_get_main_queue()) {
                    // Re-fetch all events happening in the next 24 hours
                    self?.eventsList = self!.fetchEvents()
                    // Update the UI with the above events
                    self?.tableView.reloadData()
                }
            }
        }
    }
    
    
    // Set the calendar edited by EKEventEditViewController to our chosen calendar - the default calendar.
    func eventEditViewControllerDefaultCalendarForNewEvents(controller: EKEventEditViewController) -> EKCalendar {
        return self.defaultCalendar
    }
    
}